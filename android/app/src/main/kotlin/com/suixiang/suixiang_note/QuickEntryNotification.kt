package com.suixiang.suixiang_note

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * 通知栏常驻快捷入口
 *
 * 竞品分析 P0 第二项：小部件解决「桌面能点」，通知栏解决「任何时候下拉就能点」。
 * 两者共用同一个深链 suixiang://capture，所以入口加得再多也不会各写一套逻辑。
 *
 * 实现要点：
 * - ongoing 通知由系统托管，应用进程被杀也留在通知栏；用户可手动划掉（我们不抢权限）
 * - Android 13+ 需要 POST_NOTIFICATIONS 运行时权限，未授权时静默跳过（不弹引导，不打扰）
 * - 通知本身不带「已记 N 条」之类需要后台刷新的内容——零后台任务，不做 WorkManager
 */
object QuickEntryNotification {

    private const val CHANNEL_ID = "suixiang_quick_entry"
    private const val NOTIFICATION_ID = 8801

    fun ensure(context: Context) {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        createChannel(context, nm)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            return // 未授权就安静退出，不打断用户
        }
        nm.notify(NOTIFICATION_ID, build(context))
    }

    fun remove(context: Context) {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.cancel(NOTIFICATION_ID)
    }

    /** Android 13+ 的权限申请交给 Activity 做（由 Dart 侧开关触发） */
    fun requestPermissionIfNeeded(activity: FlutterActivity) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            activity.requestPermissions(
                arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQUEST_CODE)
        }
    }

    const val REQUEST_CODE = 8802

    private fun createChannel(context: Context, nm: NotificationManager) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "快捷记录",
            NotificationManager.IMPORTANCE_LOW // LOW：不出横幅不响铃，只在抽屉里常驻
        ).apply {
            description = "在通知栏常驻一个「记一条」，下拉即可记录"
            setShowBadge(false)
            enableVibration(false)
        }
        nm.createNotificationChannel(channel)
    }

    private fun build(context: Context): Notification {
        val captureIntent = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            data = Uri.parse("suixiang://capture")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pending = PendingIntent.getActivity(
            context,
            0,
            captureIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
        return builder
            .setContentTitle("记一条")
            .setContentText("点开就能写，想到什么记什么")
            .setSmallIcon(R.mipmap.ic_launcher_foreground)
            .setContentIntent(pending)
            .setOngoing(true)
            .setShowWhen(false)
            .setPriority(Notification.PRIORITY_LOW)
            .build()
    }
}
