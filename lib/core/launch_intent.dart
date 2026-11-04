import 'dart:io';

import 'package:flutter/services.dart';

/// 启动意图：外部入口（桌面小部件 / 通知栏常驻 / 系统分享 / 长按图标快捷方式）
/// 唤起应用时，需要告诉 App「直接打开速记」而不是落在首页。
///
/// 只有一个入口类，避免每个外部入口各写一套解析：
/// - `suixiang://capture`、`suixiang://capture?text=xxx`（深链 / 小部件 / 快捷方式）
/// - 系统分享（SEND intent）：action=android.intent.action.SEND，正文在 extra 里
/// - `-capture` 命令行参数（Windows 桌面端，供未来托盘右键「记一条」复用）
class LaunchIntent {
  /// capture = 直接弹出速记面板并聚焦输入
  final String? action;

  /// 预填正文（分享进来的文字 / 预填草稿）
  final String? text;

  const LaunchIntent({this.action, this.text});

  static const none = LaunchIntent();

  bool get isCapture => action == 'capture';

  /// 长按图标的「归档」快捷方式：直接落到归档视图，不用先打开 App 再找入口
  bool get isArchived => action == 'archived';

  /// 从 URI 解析；无法识别时返回 none（不抛异常，外部输入一律不可信）
  factory LaunchIntent.parseUri(String? uri) {
    if (uri == null || uri.isEmpty) return none;
    final parsed = Uri.tryParse(uri);
    if (parsed == null) return none;
    final host = parsed.host.isNotEmpty
        ? parsed.host
        : parsed.path.replaceAll('/', '');
    if (host == 'archived') {
      return const LaunchIntent(action: 'archived');
    }
    if (host != 'capture') return none;
    final text = parsed.queryParameters['text'];
    return LaunchIntent(
      action: 'capture',
      text: (text == null || text.trim().isEmpty) ? null : text,
    );
  }

  /// 命令行参数解析（Windows / 测试）：`-capture` 或 `suixiang://capture?text=…`
  factory LaunchIntent.parseArgs(List<String> args) {
    var capture = false;
    var archived = false;
    String? text;
    for (final a in args) {
      if (a == '-capture' || a == '--capture') {
        capture = true;
      } else if (a.startsWith('suixiang://')) {
        final u = LaunchIntent.parseUri(a);
        if (u.isCapture) {
          capture = true;
          text = u.text;
        } else if (u.isArchived) {
          archived = true;
        }
      } else if (a.startsWith('-text=')) {
        text = a.substring('-text='.length);
      }
    }
    if (capture) return LaunchIntent(action: 'capture', text: text);
    if (archived) return const LaunchIntent(action: 'archived');
    return none;
  }

  /// 读取启动意图：Android/iOS 走 MethodChannel（原生侧持有首个 intent），
  /// 其它平台回落到命令行参数（仅桌面端有意义）。
  static Future<LaunchIntent> readInitial() async {
    const channel = MethodChannel('suixiang/launch');
    try {
      final raw = await channel.invokeMapMethod<String, dynamic>(
          'getInitialIntent');
      final uri = raw?['uri'] as String?;
      final sharedText = raw?['text'] as String?;
      if (sharedText != null && sharedText.trim().isNotEmpty) {
        // 系统分享：正文直接进速记，action 由原生侧置为 capture
        return LaunchIntent(
            action: (raw?['action'] as String?) ?? 'capture',
            text: sharedText);
      }
      if (uri != null) return LaunchIntent.parseUri(uri);
      final action = raw?['action'] as String?;
      if (action != null && action.trim().isNotEmpty) {
        return LaunchIntent(action: action);
      }
      return none;
    } on MissingPluginException {
      // 桌面端/未实现原生侧：读命令行参数
      return LaunchIntent.parseArgs(
          Platform.isWindows ? Platform.executableArguments : const []);
    } on PlatformException {
      return none;
    }
  }
}
