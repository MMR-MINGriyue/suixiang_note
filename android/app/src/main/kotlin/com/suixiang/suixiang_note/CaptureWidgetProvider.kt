package com.suixiang.suixiang_note

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews

/**
 * 桌面小部件「记一条」
 *
 * 竞品分析结论：随想随记最大的结构性短板是捕捉入口只有 FAB——
 * 冷启动 + 解锁 + 找图标要 5 秒以上，PRD 的「≤3 秒落库」根本不成立。
 * flomo 靠微信服务号、Keep 靠小部件 + 常驻通知，我们两个都没有。
 *
 * 这个小部件只做一件事：点一下 → 深链 suixiang://capture → 应用冷启动后
 * 直接弹速记面板并聚焦输入。零配置、零权限、不常驻进程。
 */
class CaptureWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_capture)
            val intent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_VIEW
                data = Uri.parse("suixiang://capture")
                // NEW_TASK 必需：从桌面启动要落到独立任务栈，否则复用后台任务栈
                // 会把「记一条」变成「回到上次停留的详情页」
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pending = PendingIntent.getActivity(
                context,
                appWidgetId,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pending)
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
