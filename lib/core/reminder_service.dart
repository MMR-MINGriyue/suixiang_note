import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data/app_database.dart';

/// 提醒调度服务（v1.6）
///
/// 设计取舍：**不引入 flutter_local_notifications**。
/// 理由（竞品分析 R3 + 本机依赖勘察）：本地缓存只有 timezone，没有
/// flutter_timezone，拉新依赖会拖一条不确定的依赖链；而提醒只需要
/// 「到点弹一条可点击的通知」，原生 AlarmManager + NotificationManager
/// 三十行就能做到，且不占用额外体积。
///
/// 可靠性策略是**双层兜底**，不假装能做精确定时：
///   1. 原生层：AlarmManager.setExactAndAllowWhileIdle 排一次；Doze/厂商杀后台
///      仍可能吞掉，所以重复提醒在每次触发时自行续期。
///   2. 应用层：每次冷启动与回前台做一次对账（[reconcile]），把「已过期但
///      没通知过」的提醒捞出来在应用内补提示 —— 这样即使用户从不给通知权限，
///      打开 App 也不会漏掉。
class ReminderService {
  static const _channel = MethodChannel('suixiang/reminder');

  /// 平台是否支持系统级提醒（桌面版没有，走纯应用内兜底）
  static bool get supported =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android);

  /// 排程一条提醒；已存在的同 id 会先被原生侧取消再重排
  static Future<bool> schedule(ReminderWithThought item) async {
    if (!supported) return false;
    try {
      await _channel.invokeMethod<bool>('schedule', {
        'id': item.reminder.id,
        'thoughtId': item.thought.id,
        'fireAt': item.reminder.remindAt,
        'repeatRule': item.reminder.repeatRule,
        'title': '随想随记',
        'body': item.headline,
      });
      return true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static Future<void> cancel(int reminderId) async {
    if (!supported) return;
    try {
      await _channel.invokeMethod<void>('cancel', {'id': reminderId});
    } on MissingPluginException {
      // 桌面版无原生实现，静默跳过
    } on PlatformException {
      // 忽略：原生侧取消失败不影响数据层状态
    }
  }

  /// 冷启动/回前台对账：把库里所有 active 提醒重排一遍。
  ///
  /// 用「全量重排」而不是增量同步，原因很实际：AlarmManager 的排程是进程外的，
  /// App 被清数据/重装/被系统清理后原始闹钟就没了，全量重排是唯一能自愈的方式，
  /// 而且提醒数量在个人使用规模下是几十条级别，重排开销可以忽略。
  static Future<int> rescheduleAll(AppDatabase db) async {
    if (!supported) return 0;
    final items = await db.snapshotActiveReminders();
    for (final item in items) {
      await schedule(item);
    }
    return items.length;
  }

  /// 检查精确闹钟权限（Android 12+ 需要用户在系统设置里单独授予）
  static Future<bool> canScheduleExact() async {
    if (!supported) return false;
    try {
      return await _channel.invokeMethod<bool>('canScheduleExact') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// 拉起系统的「精确闹钟」授权页（Android 12+ 路径）
  static Future<void> openExactAlarmSettings() async {
    if (!supported) return;
    try {
      await _channel.invokeMethod<void>('openExactAlarmSettings');
    } on MissingPluginException {
      // 桌面无此设置项
    } on PlatformException {
      // 用户取消或系统限制，保持当前状态即可
    }
  }

  /// 应用内兜底：把已过期但未通知的提醒取出来并标记。
  ///
  /// 返回的是「需要提示给用户」的列表，调用方负责展示（SnackBar / 弹层）。
  /// 标记为 fired 的时机在这里 —— 一旦交点就已经算送达，避免重复弹。
  static Future<List<ReminderWithThought>> reconcile(AppDatabase db) async {
    final due = await db.takeDueReminders();
    for (final item in due) {
      if (item.isRepeating) {
        // 重复提醒：只记 lastFiredAt，保持 active 让原生侧续期
        await db.markReminderFiredKeepActive(item.reminder.id);
      } else {
        await db.markReminderFired(item.reminder.id);
      }
    }
    return due;
  }
}
