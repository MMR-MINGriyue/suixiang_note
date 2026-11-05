import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/reminder_service.dart';
import '../data/app_database.dart';
import '../theme/tokens.dart';
import 'widgets/app_feedback.dart';

/// 提醒设置半屏面板（v1.6）
///
/// 交互取向：**不要日历控件**。
/// 灵感管理的提醒是「过一会儿/明天/下周想起这件事」，不是「订 3 月 14 日 15:30 的会议室」。
/// 所以给的是几个语义化快捷项 + 一个「自选时间」，点两下就能定完。
class ReminderSheet extends StatefulWidget {
  final AppDatabase db;
  final Thought thought;
  final Reminder? existing;

  const ReminderSheet({
    super.key,
    required this.db,
    required this.thought,
    this.existing,
  });

  /// 打开面板；返回值 true 表示数据有变化（调用方刷新）
  static Future<bool> open(
    BuildContext context,
    AppDatabase db,
    Thought thought,
  ) async {
    final existing = await db.watchActiveReminderOf(thought.id).first;
    if (!context.mounted) return false;
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(T.rSheet)),
      ),
      builder: (ctx) => ReminderSheet(
        db: db,
        thought: thought,
        existing: existing.isEmpty ? null : existing.first,
      ),
    );
    return changed == true;
  }

  @override
  State<ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends State<ReminderSheet> {
  late Reminder? _existing;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _existing = widget.existing;
  }

  /// 把时间归整到下一个整点/半点，避免用户选到「现在+3 秒」
  DateTime _roundUp(DateTime t) {
    final next = t.add(const Duration(hours: 1));
    return DateTime(next.year, next.month, next.day, next.hour, 0);
  }

  Future<void> _apply(DateTime fireAt, String repeatRule) async {
    if (_busy) return;
    setState(() => _busy = true);
    final db = widget.db;
    final id = await db.upsertReminder(
      thoughtId: widget.thought.id,
      remindAt: fireAt.millisecondsSinceEpoch,
      repeatRule: repeatRule,
    );
    // 重新取一次完整对象交给原生排程（需要随记标题做通知文案）
    final items = await db.watchActiveReminderOf(widget.thought.id).first;
    final item = items.where((r) => r.id == id).firstOrNull;
    if (item != null) {
      await ReminderService.schedule(
          ReminderWithThought(item, widget.thought));
    }
    if (!mounted) return;
    // 写库 + 排程完成后给一次确认；反馈挂在底层 Scaffold 上，
    // pop 之前先发出，避免半屏面板消失后 SnackBar 找不到宿主。
    AppFeedback.success(context,
        '已设定提醒 · ${DateFormat('M月d日 HH:mm').format(fireAt)}');
    Navigator.pop(context, true);
  }

  Future<void> _pickCustom() async {
    final now = DateTime.now();
    final initial = _existing != null
        ? DateTime.fromMillisecondsSinceEpoch(_existing!.remindAt)
        : _roundUp(now);
    final date = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365 * 3)),
      helpText: '提醒日期',
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      helpText: '提醒时间',
    );
    if (time == null) return;
    final fireAt =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (fireAt.isBefore(DateTime.now())) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('这个时间已经过去了，选个将来的'),
          duration: Duration(seconds: 2)));
      return;
    }
    await _apply(fireAt, _existing?.repeatRule ?? 'once');
  }

  Future<void> _clear() async {
    if (_existing == null) return;
    final ok = await AppFeedback.confirmDanger(
      context,
      title: '取消提醒',
      content: '这条随记到点不再提醒你。',
      confirmLabel: '取消提醒',
    );
    if (!ok || !mounted) return;
    await widget.db.deleteReminder(_existing!.id);
    await ReminderService.cancel(_existing!.id);
    if (!mounted) return;
    AppFeedback.success(context, '提醒已取消');
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('M月d日 HH:mm');
    final existingText = _existing == null
        ? null
        : switch (_existing!.repeatRule) {
            'daily' => '每天 ${DateFormat('HH:mm').format(DateTime.fromMillisecondsSinceEpoch(_existing!.remindAt))}',
            'weekly' => '每周 ${DateFormat('E HH:mm').format(DateTime.fromMillisecondsSinceEpoch(_existing!.remindAt))}',
            'monthly' => '每月 ${DateFormat('d日 HH:mm').format(DateTime.fromMillisecondsSinceEpoch(_existing!.remindAt))}',
            _ => fmt.format(DateTime.fromMillisecondsSinceEpoch(_existing!.remindAt)),
          };

    final now = DateTime.now();
    final tonight = DateTime(now.year, now.month, now.day, 20, 0);
    final tomorrow = DateTime(now.year, now.month, now.day + 1, 9, 0);
    final weekend = _nextWeekday(now, DateTime.saturday, 10);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: T.inkTertiary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              const Icon(Icons.notifications_active_outlined,
                  size: 20, color: T.brandPrimary),
              const SizedBox(width: 8),
              Text('提醒我',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontSize: 18, fontWeight: FontWeight.w600)),
            ]),
            if (existingText != null) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: T.brandContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  const Icon(Icons.alarm_on,
                      size: 16, color: T.brandPrimary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('已设定：$existingText',
                        style: const TextStyle(
                            fontSize: 13, color: T.brandPrimary)),
                  ),
                ]),
              ),
            ],
            const SizedBox(height: 16),
            _QuickRow(label: '今天 20:00', icon: Icons.wb_twilight,
                onTap: () => _apply(
                    tonight.isBefore(now) ? _roundUp(now) : tonight, 'once')),
            _QuickRow(label: '明天 09:00', icon: Icons.wb_sunny_outlined,
                onTap: () => _apply(tomorrow, 'once')),
            _QuickRow(label: '周六 10:00', icon: Icons.weekend_outlined,
                onTap: () => _apply(weekend, 'once')),
            _QuickRow(label: '明天起每天 09:00', icon: Icons.repeat,
                onTap: () => _apply(tomorrow, 'daily')),
            const Divider(height: 24),
            _QuickRow(
              label: '自选日期时间…',
              icon: Icons.event_outlined,
              onTap: _pickCustom,
            ),
            if (_existing != null)
              _QuickRow(
                label: '取消提醒',
                icon: Icons.notifications_off_outlined,
                danger: true,
                onTap: _clear,
              ),
            const SizedBox(height: 8),
            if (!ReminderService.supported)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  '桌面版没有系统通知，提醒只在下次打开 App 时提示',
                  style: TextStyle(fontSize: 11, color: T.inkTertiary),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 从 [from] 起下一个指定星期几（含今天之后），保持时刻
  DateTime _nextWeekday(DateTime from, int weekday, int hour) {
    var d = DateTime(from.year, from.month, from.day, hour);
    while (d.weekday != weekday || d.isBefore(from)) {
      d = d.add(const Duration(days: 1));
    }
    return d;
  }
}

class _QuickRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool danger;
  const _QuickRow({
    required this.label,
    required this.icon,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? T.danger : T.ink1(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        child: Row(children: [
          Icon(icon, size: 20, color: danger ? T.danger : T.ink2(context)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: TextStyle(fontSize: 15, color: color)),
          ),
          if (!danger)
            Icon(Icons.chevron_right, size: 18, color: T.ink3(context)),
        ]),
      ),
    );
  }
}
