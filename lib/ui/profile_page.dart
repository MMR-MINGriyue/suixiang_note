import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/backup_service.dart';
import '../main.dart' show appDb, themeModeNotifier;
import '../theme/tokens.dart';

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

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (mounted) setState(() => _themeMode = p.getString('theme_mode') ?? 'system');
    });
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
          _SectionHeader('外观'),
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
          _SectionHeader('数据'),
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
              ListTile(
                leading: const Icon(Icons.delete_sweep_outlined, color: T.danger),
                title: const Text('清空回收站'),
                subtitle: const Text('永久删除回收站内的随记'),
                onTap: _emptyTrash,
              ),
            ]),
          ),
          _SectionHeader('关于'),
          Card(
            child: Column(children: [
              const ListTile(
                leading: Icon(Icons.water_drop_outlined, color: T.brandPrimary),
                title: Text('随想随记'),
                subtitle: Text('v1.0 · 本地优先 · 无账号无云同步'),
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

  void _showSheet(BuildContext context, String title, String body) {
    showModalBottomSheet<void>(
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
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(text,
          style: TextStyle(
              color: T.inkSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }
}
