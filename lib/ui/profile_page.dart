import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/reminder_service.dart';
import '../data/backup_service.dart';
import '../data/app_database.dart';
import '../main.dart' show appDb, themeModeNotifier;
import '../theme/tokens.dart';
import 'tag_manage_page.dart';
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
    // 启动时把库里所有 active 提醒重排一遍：AlarmManager 的排程在进程外，
    // App 被重装/清数据/系统清理后原始闹钟就没了，全量重排是唯一能自愈的方式
    ReminderService.rescheduleAll(appDb);
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
        action: SnackBarAction(
          label: '打开目录',
          onPressed: () => Process.run('explorer.exe', [File(path).parent.path]),
        ),
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
                leading: const Icon(Icons.label_outline, color: T.brandPrimary),
                title: const Text('标签管理'),
                subtitle: const Text('查看、重命名、换色、删除标签'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => TagManagePage(db: appDb))),
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
                          await appDb.deleteReminder(it.reminder.id);
                          await ReminderService.cancel(it.reminder.id);
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
                subtitle: const Text('v1.0 · 本地优先 · 无账号无云同步'),
                onTap: _onVersionTap,
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('隐私说明'),
                subtitle: const Text('所有数据仅保存在本机'),
                onTap: () => _showSheet(context, '隐私说明',
                    '随想随记不联网、不收集任何数据。\n全部随记、文件夹与设置仅存储于本机应用目录，你可以在「数据」中随时备份导出。'),
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

  void _showSheet(BuildContext context, String title, String body) {    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(T.rSheet))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(ctx).textTheme.titleLarge),
          const SizedBox(height: 12),
          Text(body),
          const SizedBox(height: 20),
        ]),
      ),
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
          StreamBuilder<List<Thought>>(
            stream: db.watchList(),
            builder: (context, snap) {
              final list = snap.data ?? const <Thought>[];
              final total = list.length;
              final inProgress =
                  list.where((t) => t.stageId == 2).length;
              final done = list.where((t) => t.stageId == 3).length;
              return Row(
                children: [
                  _Stat(value: total, label: '全部'),
                  _statDivider(),
                  _Stat(value: inProgress, label: '推进'),
                  _statDivider(),
                  _Stat(value: done, label: '完成'),
                ],
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
