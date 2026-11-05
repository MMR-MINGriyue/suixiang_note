package com.suixiang.suixiang_note

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import java.util.Calendar

/**
 * 提醒排程器：只管「排 / 撤 / 续期」三个动作。
 *
 * 为什么用 setExactAndAllowWhileIdle 而不是 WorkManager：
 * WorkManager 的最短周期是 15 分钟且不保证准点，提醒场景下「9:00 的闹钟 9:20 才响」
 * 就是功能失效。代价是需要 SCHEDULE_EXACT_ALARM（Android 12+ 用户可关闭），
 * 所以调用方必须能容忍降级：拿不到精确权限时退回 setAndAllowWhileIdle。
 */
object ReminderScheduler {

    const val EXTRA_ID = "reminder_id"
    const val EXTRA_THOUGHT_ID = "thought_id"
    const val EXTRA_TITLE = "reminder_title"
    const val EXTRA_BODY = "reminder_body"
    const val EXTRA_REPEAT = "reminder_repeat"
    // 原始排程时刻：重复提醒续期必须从这个基准推，而不是从「响铃的当前时间」推，
    // 否则 Doze 延迟响铃会让每天的提醒逐日漂移。见架构复审 P0-2。
    const val EXTRA_FIRE_AT = "reminder_fire_at"

    private const val REQ_OFFSET = 10_000

    private fun pendingIntent(context: Context, id: Int, extras: Map<String, Any?>?): PendingIntent {
        val intent = Intent(context, ReminderReceiver::class.java).apply {
            putExtra(EXTRA_ID, id)
            extras?.forEach { (k, v) ->
                when (v) {
                    is Int -> putExtra(k, v)
                    is Long -> putExtra(k, v)
                    is String -> putExtra(k, v)
                }
            }
        }
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            flags = flags or PendingIntent.FLAG_IMMUTABLE
        }
        return PendingIntent.getBroadcast(context, id + REQ_OFFSET, intent, flags)
    }

    /** 排一条提醒；同 id 重复调用会覆盖旧闹钟（不会叠加响两次） */
    fun schedule(
        context: Context,
        id: Int,
        thoughtId: Int,
        fireAt: Long,
        repeatRule: String,
        title: String,
        body: String,
    ) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = pendingIntent(context, id, mapOf(
            EXTRA_THOUGHT_ID to thoughtId,
            EXTRA_TITLE to title,
            EXTRA_BODY to body,
            EXTRA_REPEAT to repeatRule,
            EXTRA_FIRE_AT to fireAt,
        ))

        val canExact = canScheduleExact(context)
        try {
            if (canExact) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, fireAt, pi)
                } else {
                    am.setExact(AlarmManager.RTC_WAKEUP, fireAt, pi)
                }
            } else {
                // 拿不到精确权限：退回非精确但允许打盹期唤醒的模式。
                // 用户会晚几分钟收到，比收不到好。
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, fireAt, pi)
            }
        } catch (e: SecurityException) {
            // 系统在排程瞬间收回了权限（用户刚关掉），退回非精确
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, fireAt, pi)
        }
    }

    fun cancel(context: Context, id: Int) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        am.cancel(pendingIntent(context, id, null))
    }

    fun canScheduleExact(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        return am.canScheduleExactAlarms()
    }

    /**
     * 重复提醒续期：算出下一次触发时刻并重排。
     * 只支持 day / week / month 三种单位 —— 更复杂的规则（每两周的周二）属于日历应用，
     * 不是灵感管理该背的复杂度。
     */
    fun rescheduleRepeat(
        context: Context,
        id: Int,
        thoughtId: Int,
        repeatRule: String,
        title: String,
        body: String,
        from: Long,
    ) {
        val next = nextOccurrence(repeatRule, from) ?: return
        schedule(context, id, thoughtId, next, repeatRule, title, body)
    }

    fun nextOccurrence(repeatRule: String, from: Long): Long? {
        val cal = Calendar.getInstance().apply { timeInMillis = from }
        when (repeatRule) {
            "daily" -> cal.add(Calendar.DAY_OF_YEAR, 1)
            "weekly" -> cal.add(Calendar.WEEK_OF_YEAR, 1)
            "monthly" -> cal.add(Calendar.MONTH, 1)
            else -> return null
        }
        return cal.timeInMillis
    }
}
