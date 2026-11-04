package com.suixiang.suixiang_note

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.util.Log

/**
 * 提醒到点广播接收器。
 *
 * 收到广播后做三件事：
 *   1. 发一条可点击的通知（点击深链到该条随记）
 *   2. 若是重复提醒，算出下一次并再排一次（AlarmManager 不会自动循环）
 *   3. 把「已触发」状态回写 —— 由 App 下次启动时做对账（原生侧不碰数据库，
 *      避免在 Kotlin 里再实现一遍 SQLite schema 而漂移）
 */
class ReminderReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "ReminderReceiver"
        const val CHANNEL_ID = "suixiang_reminder"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getIntExtra(ReminderScheduler.EXTRA_ID, -1)
        if (id < 0) return
        val thoughtId = intent.getIntExtra(ReminderScheduler.EXTRA_THOUGHT_ID, -1)
        val title = intent.getStringExtra(ReminderScheduler.EXTRA_TITLE) ?: "随想随记"
        val body = intent.getStringExtra(ReminderScheduler.EXTRA_BODY) ?: "到点了"
        val repeat = intent.getStringExtra(ReminderScheduler.EXTRA_REPEAT) ?: "once"

        try {
            showNotification(context, id, thoughtId, title, body)
        } catch (e: SecurityException) {
            // Android 13+ 用户没给通知权限：静默失败。
            // 应用内对账仍会在用户下次打开时补提示，不留数据损失。
            Log.w(TAG, "notification permission missing", e)
        }

        if (repeat != "once") {
            ReminderScheduler.rescheduleRepeat(
                context = context,
                id = id,
                thoughtId = thoughtId,
                repeatRule = repeat,
                title = title,
                body = body,
                from = System.currentTimeMillis(),
            )
        }
    }

    private fun showNotification(
        context: Context,
        id: Int,
        thoughtId: Int,
        title: String,
        body: String,
    ) {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "随记提醒",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "到点提醒你看某条随记"
                enableVibration(true)
            }
            nm.createNotificationChannel(channel)
        }

        // 点击通知 -> 打开 App 并直达该条随记（复用 v1.5 的深链协议）
        val openIntent = Intent(Intent.ACTION_VIEW, Uri.parse("suixiang://thought/$thoughtId")).apply {
            setClass(context, MainActivity::class.java)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        var piFlags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            piFlags = piFlags or PendingIntent.FLAG_IMMUTABLE
        }
        val contentPi = PendingIntent.getActivity(context, id, openIntent, piFlags)

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }

        val notification = builder
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setSmallIcon(R.mipmap.ic_launcher_monochrome)
            .setAutoCancel(true)
            .setContentIntent(contentPi)
            .setWhen(System.currentTimeMillis())
            .setShowWhen(true)
            .build()

        nm.notify(id, notification)
    }
}
