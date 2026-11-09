import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_info.dart';
import '../core/reminder_service.dart';
import '../data/backup_service.dart';
import '../data/app_database.dart';
import '../core/app_signals.dart';
import '../theme/tokens.dart';
import 'daily_review_page.dart';
import 'graph_page.dart';
import 'tag_manage_page.dart';
import 'widgets/app_feedback.dart';
import 'widgets/drop_badge.dart';

/// Tab 2 我的（M6 设置闭环，v1.0 按 PM 评审「9 行」收敛版）：
/// 外观（深色模式）· 记录偏好（列表排序/触感）· 数据（备份/恢复/清空回收站）· 关于
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String _themeMode = 'system';
  late final BackupService _backup = BackupService(appDb);
  int _versionTaps = 0; // 创意 ⑦-4：版本行 7 连击彩蛋计数

  /// 通知栏常驻入口开关（竞品分析 P0 第二项）。
  /// 状态存在 SharedPreferences，实际的通知由 Android 原生侧 setQuickEntry 通道管理。
  bool _quickEntry = false;
  static const _launchChannel = MethodChannel('suixiang/launch');

  /// 精确闹钟权限（Android 12+）。false 时提醒会降级为非精确，页面上要给提示。
  bool _exactAlarmOk = true;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (!mounted) return;
      setState(() {
        _themeMode = p.getString('theme_mode') ?? 'system';
        _quickEntry = p.getBool('quick_entry_on') ?? false;
      });
    });
    // （架构复审 P1-2：启动全量重排收敛到 main.dart 首帧对账一次，
    // 这里不再 rescheduleAll——原来冷启动会全量重排两遍）
    ReminderService.canScheduleExact().then((ok) {
      if (!mounted) return;
      setState(() => _exactAlarmOk = ok);
    });
  }

  /// 提醒时间的人话表述（重复提醒显示规则，一次性显示具体时刻）
  String _reminderLabel(ReminderWithThought it) {
    final at = DateTime.fromMillisecondsSinceEpoch(it.reminder.remindAt);
    return switch (it.reminder.repeatRule) {
      'daily' => '每天 ${DateFormat('HH:mm').format(at)}',
      'weekly' => '每周 ${DateFormat('E HH:mm').format(at)}',
      'monthly' => '每月 ${DateFormat('d日 HH:mm').format(at)}',
      _ => DateFormat('M月d日 HH:mm').format(at),
    };
  }

  Future<void> _toggleQuickEntry(bool on) async {
    setState(() => _quickEntry = on);
    final p = await SharedPreferences.getInstance();
    await p.setBool('quick_entry_on', on);
    try {
      await _launchChannel.invokeMethod('setQuickEntry', {'enabled': on});
    } on MissingPluginException {
      // 桌面端没有通知栏；不打扰用户，仅在设置里保留开关状态
    } on PlatformException {
      // 权限被拒绝等情况：原生侧会静默失败，这里不弹错误打断记录
    }
  }

  Future<void> _setThemeMode(String mode) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('theme_mode', mode);
    if (!mounted) return;
    setState(() => _themeMode = mode);
    // 主题热切换：ValueNotifier 驱动 MaterialApp 即时生效，无需重启
    themeModeNotifier.value = switch (mode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> _backupNow() async {
    try {
      final path = await _backup.backupNow();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('备份完成：${Uri.file(path).pathSegments.last}'),
        action: Platform.isWindows
            ? SnackBarAction(
                label: '打开目录',
                onPressed: () =>
                    Process.run('explorer.exe', [File(path).parent.path]),
              )
            : null, // 架构评审 E3：explorer.exe 是 Windows 专属，Android 上不显示
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('备份失败：$e')));
    }
  }

  Future<void> _restoreFlow() async {
    final backups = await _backup.listBackups();
    if (!mounted) return;
    if (backups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('还没有备份文件，先「立即备份」一次')));
      return;
    }
    final picked = await showDialog<File>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('选择要恢复的备份'),
        content: SizedBox(
          width: 360,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: backups.length,
            itemBuilder: (_, i) {
              final f = backups[i];
              final stamp = f.uri.pathSegments.last
                  .replaceAll('suixiang_backup_', '')
                  .replaceAll('.json', '');
              final dt = DateTime.tryParse(
                  '${stamp.substring(0, 8)}T${stamp.substring(9, 15)}');
              final title = dt == null
                  ? f.uri.pathSegments.last
                  : DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);
              return ListTile(
                leading: const Icon(Icons.restore, color: T.brandPrimary),
                title: Text(title),
                subtitle: Text('${(f.lengthSync() / 1024).toStringAsFixed(1)} KB'),
                onTap: () => Navigator.pop(ctx, f),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        ],
      ),
    );
    if (picked == null || !mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认恢复'),
        content: const Text('恢复会用备份内容替换当前全部数据（恢复前会自动对当前数据再做一次备份）。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('恢复'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final count = await _backup.restoreFrom(picked);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('恢复完成：共 $count 条随记')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('恢复失败：$e')));
    }
  }

  Future<void> _emptyTrash() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空回收站'),
        content: const Text('将永久删除回收站里的全部随记，此操作不可撤销。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: T.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await appDb.purgeTrash();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('回收站已清空')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的'), backgroundColor: Colors.transparent),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // 品牌头卡（创意 ⑦-1）：水滴 Logo + 总览数据（总数/推进中/已完成）
          _BrandHeader(db: appDb),
          const SizedBox(height: 16),
          _SectionHeader('外观', color: T.brandPrimary),
          Card(
            child: RadioGroup<String>(
              groupValue: _themeMode,
              onChanged: (v) => _setThemeMode(v!),
              child: Column(children: [
                RadioListTile<String>(
                  value: 'system',
                  title: const Text('跟随系统'),
                ),
                RadioListTile<String>(
                  value: 'light',
                  title: const Text('浅色'),
                ),
                RadioListTile<String>(
                  value: 'dark',
                  title: const Text('深色'),
                ),
              ]),
            ),
          ),
          _SectionHeader('整理', color: T.stageInspiration),
          Card(
            child: Column(children: [
              ListTile(
                // 图标规范①：入口行统一 outlined（点击后才进入填充语义的页面）
                leading: const Icon(Icons.label_outline, color: T.brandPrimary),
                title: const Text('标签管理'),
                subtitle: const Text('查看、重命名、换色、删除标签'),
                // 图标规范④：chevron 统一弱色——它是「还有下级」的形状标记，
                // 不该和内容图标抢视觉权重
                trailing: Icon(Icons.chevron_right,
                    size: 22,
                    color: T.ink3Of(
                        Theme.of(context).brightness == Brightness.dark)),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => TagManagePage(db: appDb))),
              ),
              // 每日回顾（v1.7）：首页 AppBar 有入口，这里再放一个——
              // 它是「每天该做一次的仪式」，藏在单个图标里容易被长期忽略
              FutureBuilder<bool>(
                future: appDb.reviewedToday(),
                builder: (context, snap) {
                  final done = snap.data == true;
                  final dark =
                      Theme.of(context).brightness == Brightness.dark;
                  return ListTile(
                    leading: const Icon(Icons.auto_awesome_outlined,
                        color: T.brandPrimary),
                    title: const Text('每日回顾'),
                    subtitle: Text(done
                        ? '今天已回顾 · 明天再来翻一翻'
                        : '翻出几条很久没碰的想法，重新看一遍'),
                    trailing: done
                        ? const Icon(Icons.check_circle,
                            size: 20, color: T.stageDone)
                        : Icon(Icons.chevron_right,
                            size: 22, color: T.ink3Of(dark)),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => DailyReviewPage(db: appDb)),
                    ),
                  );
                },
              ),
              // 关系图谱入口：整理组里唯一的「看整体」的视图，
              // 另外三个都是「逐条改」的工具
              ListTile(
                leading: const Icon(Icons.hub_outlined, color: T.stageDone),
                title: const Text('关系图谱'),
                subtitle: const Text('看随记之间连成了什么形状'),
                trailing: Icon(Icons.chevron_right,
                    size: 22,
                    color: T.ink3Of(
                        Theme.of(context).brightness == Brightness.dark)),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => GraphPage(db: appDb))),
              ),
              // 竞品分析 P0：捕捉入口不能只有 FAB——冷启动+解锁找图标 >5 秒，
              // 「≤3 秒落库」不成立。桌面小部件已默认可用，这里补通知栏常驻。
              SwitchListTile(
                secondary:
                    const Icon(Icons.notifications_active_outlined, color: T.brandPrimary),
                title: const Text('通知栏常驻「记一条」'),
                subtitle: const Text('下拉通知栏点一下就能写；不需要时可随时关掉'),
                value: _quickEntry,
                onChanged: _toggleQuickEntry,
              ),
            ]),
          ),
          _SectionHeader('提醒', color: T.warning),
          Card(
            child: StreamBuilder<List<ReminderWithThought>>(
              stream: appDb.watchUpcomingReminders(),
              builder: (context, snap) {
                final items = snap.data ?? const <ReminderWithThought>[];
                if (items.isEmpty) {
                  return const ListTile(
                    leading: Icon(Icons.notifications_none,
                        color: T.inkTertiary),
                    title: Text('还没有提醒'),
                    subtitle: Text('在随记详情页点铃铛，就能让它到点提醒你'),
                  );
                }
                return Column(children: [
                  for (final it in items.take(8))
                    ListTile(
                      dense: true,
                    leading: Icon(
                      // 图标规范①：重复提醒用 repeat 表达「会再来」，
                      // 一次性用 alarm（outlined 家族，20px 菜单档）
                      it.isRepeating ? Icons.repeat : Icons.alarm,
                      size: 20,
                      color: T.brandPrimary,
                    ),
                      title: Text(it.headline,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14)),
                      subtitle: Text(_reminderLabel(it),
                          style:
                              const TextStyle(fontSize: 11, color: T.inkTertiary)),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        tooltip: '取消这个提醒',
                        onPressed: () async {
                          final ok = await AppFeedback.confirmDanger(
                            context,
                            title: '取消提醒',
                            content: '「${it.headline}」到点不再提醒你。',
                            confirmLabel: '取消提醒',
                          );
                          if (!ok || !context.mounted) return;
                          await appDb.deleteReminder(it.reminder.id);
                          await ReminderService.cancel(it.reminder.id);
                          if (!context.mounted) return;
                          AppFeedback.success(context, '提醒已取消');
                        },
                      ),
                    ),
                  if (items.length > 8)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                      child: Text('另有 ${items.length - 8} 条待提醒',
                          style: const TextStyle(
                              fontSize: 11, color: T.inkTertiary)),
                    ),
                ]);
              },
            ),
          ),
          if (ReminderService.supported && !_exactAlarmOk)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
              child: InkWell(
                onTap: () async {
                  await ReminderService.openExactAlarmSettings();
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: T.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(children: [
                    Icon(Icons.info_outline, size: 16, color: T.warning),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '系统未允许精确提醒，闹钟可能晚几分钟。点此去开启',
                        style: TextStyle(fontSize: 12, color: T.inkSecondary),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          _SectionHeader('数据', color: T.stageDone),
          Card(
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.backup_outlined, color: T.brandPrimary),
                title: const Text('立即备份'),
                subtitle: const Text('导出全部数据为 JSON 快照（保留最近 7 份）'),
                onTap: _backupNow,
              ),
              ListTile(
                leading: const Icon(Icons.restore_outlined, color: T.brandPrimary),
                title: const Text('恢复备份'),
                subtitle: const Text('从快照恢复全部数据'),
                onTap: _restoreFlow,
              ),
            ]),
          ),
          // 创意 ⑦-3：危险区隔离——独立成卡 + dangerContainer 图标底，与常规数据操作隔开
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? T.darkDangerContainer
                      : T.dangerContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.delete_sweep_outlined,
                    size: 20, color: T.danger),
              ),
              title: const Text('清空回收站'),
              subtitle: const Text('永久删除回收站内的随记'),
              onTap: _emptyTrash,
            ),
          ),
          _SectionHeader('关于', color: T.inkSecondary),
          Card(
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.water_drop_outlined, color: T.brandPrimary),
                title: const Text('随想随记'),
                // 版本号来自 core/app_info.dart，与 pubspec.yaml 同源校验，
                // 不再手写——之前这里写死「v1.0」，实际已经跑到 1.8 了。
                subtitle: Text('v$kAppVersionShort · 本地优先 · 无账号无云同步'),
                onTap: _onVersionTap,
              ),
              ListTile(
                leading: const Icon(Icons.shield_outlined),
                title: const Text('隐私与数据说明'),
                // 这一行把最容易被误解的事写在了明面上：
                // 电脑和手机是两套独立数据库，不自动同步。
                subtitle: const Text('不联网 · 数据全在本机 · 各设备独立'),
                onTap: () => _showPrivacySheet(context),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  /// 创意 ⑦-4：版本行 7 连击彩蛋——三颗水滴依次点亮 + SnackBar
  void _onVersionTap() {
    _versionTaps++;
    if (_versionTaps < 7) return;
    _versionTaps = 0;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            DropBadge(kind: 'inspiration', color: T.stageInspiration, size: 28),
            SizedBox(width: 12),
            DropBadge(kind: 'in_progress', color: T.stageInProgress, size: 28),
            SizedBox(width: 12),
            DropBadge(kind: 'done', color: T.stageDone, size: 28),
          ]),
          const SizedBox(height: 16),
          Text('水滴已集齐',
              style: Theme.of(ctx).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text('灵感 → 推进 → 完成，每一滴都算数',
              style: TextStyle(fontSize: 12, color: T.inkSecondary)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('收下')),
        ],
      ),
    );
  }

  /// 隐私与数据说明：竞品分析点出的两个「预期管理」问题在这里一次性说清。
  ///  1. Windows 与手机是两套独立数据库（不自动同步）——这是误解型数据事故的温床；
  ///  2. 数据库是明文的——本机之外任何人拿到文件就能读。
  /// 文案原则：不承诺做不到的事，也不吓唬人。说清「丢了会怎样」比说「很安全」有用。
  void _showPrivacySheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(T.rSheet))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        maxChildSize: 0.92,
        builder: (ctx, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Center(
              child: Container(
                width: 32,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: T.inkTertiary.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text('隐私与数据说明', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 16),
            _PrivacyBlock(
              icon: Icons.wifi_off_outlined,
              title: '不联网',
              body: '这个应用没有任何网络请求。没有账号、没有登录、没有统计上报，'
                  '也没有云端。写下的东西只落在这台设备的文件里。',
            ),
            _PrivacyBlock(
              icon: Icons.devices_other_outlined,
              title: '电脑和手机是两套独立数据',
              body: '在电脑上记的内容不会出现在手机上，反之亦然。两边的备份文件也互相独立。\n\n'
                  '这是刻意的设计（本地优先、零依赖），但它有一个真实代价：'
                  '如果你以为它们在同步，可能在换设备后发现「东西不见了」。'
                  '建议固定在一台主力设备上记录，需要迁移时用「数据 → 立即备份 / 恢复备份」手动搬。',
              emphasis: true,
            ),
            _PrivacyBlock(
              icon: Icons.lock_open_outlined,
              title: '数据库是明文的',
              body: '随记正文以明文存储在本地数据库文件中，没有加密。'
                  '任何能访问这台设备文件的人（或拿到备份 JSON 文件的人）都可以直接读取内容。\n\n'
                  '如果你会记录不适合被他人看到的内容，请自行妥善保管设备，'
                  '并且不要把备份文件放在共享目录或同步盘里。',
              emphasis: true,
            ),
            _PrivacyBlock(
              icon: Icons.folder_outlined,
              title: '数据在哪里',
              body: '数据库：应用私有目录下的 $kDatabaseName.sqlite\n'
                  '备份：$kBackupFolderName（在系统「文档」目录下，卸载应用不会被删除）\n\n'
                  '备份保留最近 7 份，超出后按时间清理最旧的。',
            ),
            _PrivacyBlock(
              icon: Icons.delete_outline,
              title: '什么情况下数据会丢',
              body: '· 卸载应用或清除应用数据 → 数据库消失，备份不消失\n'
                  '· 手机丢失 / 损坏 / 重置 → 两者都可能消失，取决于是否有外部副本\n'
                  '· 系统空间不足时应用被杀 → 不会丢（每次输入都会落库），但未保存的输入可能丢\n\n'
                  '唯一可靠的自救方式是定期做备份，并把备份文件复制到设备之外（U 盘、'
                  '你自己的网盘、另一台电脑）。',
            ),
            const SizedBox(height: 8),
            Text('以上为应用当前的真实行为，不是免责声明模板。若与实际不符，'
                '请以「数据」中的备份文件内容为准。',
                style: TextStyle(fontSize: 12, color: T.inkTertiary, height: 1.6)),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('知道了'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 隐私说明里的一段：图标 + 标题 + 正文
/// emphasis=true 的段落用 warning 色描边——这两条是「容易误解成事故」的部分，
/// 排版上必须比其它段落更显眼，否则用户会跳过。
class _PrivacyBlock extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final bool emphasis;
  const _PrivacyBlock({
    required this.icon,
    required this.title,
    required this.body,
    this.emphasis = false,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: emphasis
            ? T.warning.withValues(alpha: dark ? 0.10 : 0.07)
            : (dark ? T.darkCardAlt : T.paperCardAlt),
        borderRadius: BorderRadius.circular(14),
        border: emphasis
            ? Border.all(color: T.warning.withValues(alpha: 0.45), width: 1)
            : null,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 18, color: emphasis ? T.warning : T.inkSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(title,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: emphasis ? T.warning : null)),
          ),
        ]),
        const SizedBox(height: 8),
        Text(body, style: const TextStyle(fontSize: 13, height: 1.65)),
      ]),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  final Color color; // 每组一色：外观=靛蓝、整理=雾靛、数据=珠绿、关于=墨蓝
  const _SectionHeader(this.text, {this.color = T.brandPrimary});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Row(children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(text,
            style: const TextStyle(
                color: T.inkSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5)),
      ]),
    );
  }
}

/// 品牌头卡（美化 P1 ⑦-1）：水滴 Logo + 三态总览数据
class _BrandHeader extends StatelessWidget {
  final AppDatabase db;
  const _BrandHeader({required this.db});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? T.darkCardAlt : T.paperCardAlt,
        borderRadius: BorderRadius.circular(T.rCard + 4),
      ),
      child: Row(
        children: [
          // 48px 水滴 Logo：完成态实心 + 品牌色（最小装饰实现，零自定义绘制）
          const DropBadge(kind: 'done', color: T.brandPrimary, size: 48),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('随想随记', style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text('每一滴想法，都值得被接住',
                    style: TextStyle(fontSize: 12, color: T.inkSecondary)),
              ],
            ),
          ),
          // 三态计数（StreamBuilder 长连一条 watchList；量级小可接受）
          // 按 stage.kind 判而非硬编码 stageId==2/3：种子 id 恰好是 1/2/3，
          // 但换库/导入后 id 不保证，写死等于埋一个只在分享备份时才爆的雷。
          StreamBuilder<List<Thought>>(
            stream: db.watchList(),
            builder: (context, snap) {
              final list = snap.data ?? const <Thought>[];
              return StreamBuilder<List<Stage>>(
                stream: db.watchStages(),
                builder: (context, stageSnap) {
                  final stages = stageSnap.data ?? const <Stage>[];
                  int countOf(String kind) {
                    final ids = stages
                        .where((s) => s.kind == kind)
                        .map((s) => s.id)
                        .toSet();
                    return list.where((t) => ids.contains(t.stageId)).length;
                  }

                  return Row(
                    children: [
                      _Stat(value: list.length, label: '全部'),
                      _statDivider(),
                      _Stat(value: countOf('in_progress'), label: '推进'),
                      _statDivider(),
                      _Stat(value: countOf('done'), label: '完成'),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _statDivider() => Container(
      width: 1, height: 20, color: T.inkTertiary.withValues(alpha: 0.3));
}

class _Stat extends StatelessWidget {
  final int value;
  final String label;
  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        children: [
          Text('$value',
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700)),
          Text(label,
              style: const TextStyle(fontSize: 10, color: T.inkTertiary)),
        ],
      ),
    );
  }
}
