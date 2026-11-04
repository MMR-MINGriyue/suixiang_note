package com.suixiang.suixiang_note

import android.content.Intent
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * 随想随记 MainActivity
 *
 * 只做一件事：把「外部唤起」的信息交给 Flutter 侧（深链 / 系统分享 / 快捷方式）。
 * 解析逻辑全部在 Dart（lib/core/launch_intent.dart），原生侧只负责搬运原始数据，
 * 避免同一套协议在 Kotlin 和 Dart 里各写一遍而漂移。
 */
class MainActivity : FlutterActivity() {

    private var initialIntentPayload: Map<String, Any?>? = null
    private var channel: MethodChannel? = null
    private var pendingUri: String? = null
    private var pendingText: String? = null
    private var pendingAction: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // 必须在 super.onCreate 之前抓 intent：Flutter Engine 起来时 channel 才注册
        captureIntent(intent)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "suixiang/launch")
        channel = ch
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialIntent" -> {
                    // 优先返回已经攒下的（冷启动时捕获的），否则返回最近一次的
                    val payload = initialIntentPayload
                    initialIntentPayload = null
                    result.success(payload ?: consumePending())
                }
                "setQuickEntry" -> {
                    // 通知栏常驻入口开关（Dart 侧设置页驱动）
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    if (enabled) {
                        QuickEntryNotification.requestPermissionIfNeeded(this)
                        QuickEntryNotification.ensure(this)
                    } else {
                        QuickEntryNotification.remove(this)
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // 提醒排程通道（v1.6）：Dart 侧算好时间点，原生只负责排/撤/续期
        val reminderCh = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "suixiang/reminder")
        reminderCh.setMethodCallHandler { call, result ->
            when (call.method) {
                "schedule" -> {
                    val id = call.argument<Int>("id") ?: -1
                    val thoughtId = call.argument<Int>("thoughtId") ?: -1
                    val fireAt = (call.argument<Number>("fireAt"))?.toLong() ?: 0L
                    val repeatRule = call.argument<String>("repeatRule") ?: "once"
                    val title = call.argument<String>("title") ?: "随想随记"
                    val body = call.argument<String>("body") ?: ""
                    if (id < 0 || fireAt <= 0L) {
                        result.success(false)
                    } else {
                        ReminderScheduler.schedule(
                            this, id, thoughtId, fireAt, repeatRule, title, body)
                        result.success(true)
                    }
                }
                "cancel" -> {
                    val id = call.argument<Int>("id") ?: -1
                    if (id >= 0) ReminderScheduler.cancel(this, id)
                    result.success(true)
                }
                "canScheduleExact" -> result.success(ReminderScheduler.canScheduleExact(this))
                "openExactAlarmSettings" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        try {
                            startActivity(Intent(
                                android.provider.Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
                                android.net.Uri.parse("package:$packageName")))
                        } catch (e: Exception) {
                            // 部分 ROM 没有这个设置页，静默失败即可
                        }
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // 应用已在后台时被二次唤起：不重建 Activity，直接推给 Dart
        captureIntent(intent)
        consumePending()?.let { payload ->
            channel?.invokeMethod("onIntent", payload)
        }
    }

    override fun onResume() {
        super.onResume()
        // 应用回到前台时补一次：若用户在通知栏/小部件点进来但 Activity 未被重建
        // （launchMode=singleTop 且任务栈已在），channel 已就绪，直接推
        consumePending()?.let { payload ->
            channel?.invokeMethod("onIntent", payload)
        }
    }

    /** 从 Intent 里抽 uri / 分享正文 / 自定义 action，只做搬运不做判断 */
    private fun captureIntent(intent: Intent?) {
        if (intent == null) return
        when (intent.action) {
            Intent.ACTION_SEND -> {
                val text = intent.getStringExtra(Intent.EXTRA_TEXT)
                if (!text.isNullOrBlank()) {
                    pendingText = text
                    pendingAction = "capture"
                }
            }
            Intent.ACTION_VIEW -> {
                val uri = intent.dataString
                if (!uri.isNullOrBlank()) {
                    pendingUri = uri
                    pendingAction = "capture"
                }
            }
            else -> {
                // 快捷方式 / 小部件可以带自定义 action；也兼容 extra 传参
                val shortcut = intent.getStringExtra("suixiang_action")
                if (!shortcut.isNullOrBlank()) pendingAction = shortcut
                val text = intent.getStringExtra(Intent.EXTRA_TEXT)
                if (!text.isNullOrBlank()) {
                    pendingText = text
                    pendingAction = "capture"
                }
            }
        }
    }

    /** 取出并清空待处理载荷（一次性消费，避免重复弹速记） */
    private fun consumePending(): Map<String, Any?>? {
        if (pendingUri == null && pendingText == null && pendingAction == null) return null
        val payload = mapOf<String, Any?>(
            "uri" to pendingUri,
            "text" to pendingText,
            "action" to pendingAction,
        )
        pendingUri = null
        pendingText = null
        pendingAction = null
        return payload
    }
}
