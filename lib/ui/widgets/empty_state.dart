import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// 统一空态组件（创意 ④-3/⑥-4）：预渲染线稿插画 + 标题 + 副文案 + 可选动作。
/// 插画为 160×120 PNG 位图（2x 超采样生成），深色主题用 ColorFiltered 调色。
class EmptyState extends StatelessWidget {
  /// assets/illus/ 下的文件名，如 'empty_home.png'
  final String illus;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.illus,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ColorFiltered(
              // 深色模式：线稿提亮（雾靛 → 浅雾靛），透明底不受影响
              colorFilter: dark
                  ? const ColorFilter.mode(Color(0xFFC9D6F2), BlendMode.srcATop)
                  : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
              child: Image.asset(
                'assets/illus/$illus',
                width: 160,
                height: 120,
                filterQuality: FilterQuality.medium,
              ),
            ),
            const SizedBox(height: 20),
            Text(title,
                style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!,
                  style:
                      theme.textTheme.bodySmall?.copyWith(color: T.inkSecondary),
                  textAlign: TextAlign.center),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// 纸纹背景（创意 ③-4）：8×8 预渲染噪点平铺，仅叠在静态背景容器上。
/// 透明度浅色 3% / 深色 1.5%（由调用侧 Opacity 控制），不做实时噪声。
class PaperTexture extends StatelessWidget {
  final Widget child;
  const PaperTexture({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: Opacity(
              opacity: dark ? 0.015 : 0.03,
              child: Image.asset(
                dark
                    ? 'assets/texture/paper_texture_dark.png'
                    : 'assets/texture/paper_texture_light.png',
                repeat: ImageRepeat.repeat,
                filterQuality: FilterQuality.none,
                gaplessPlayback: true,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
