import 'package:flutter/material.dart';

/// 统一空态组件（创意 ④-3/⑥-4）：预渲染线稿插画 + 标题 + 副文案 + 可选动作。
/// 插画为 320×240 PNG 位图（2x 资产，按 160×120 逻辑像素显示）。
/// 深色模式不再整图刷单色（v2.4.1 修复：琥珀液面/闪星必须保留），
/// 改为 Image 原色显示——插画自带暖光斑与琥珀，在深底上自然提亮。
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // v2.4.1：深色模式不再整图刷单色（会把琥珀液面/闪星吃掉），
            // 插画自带暖光斑与琥珀，直接原色显示。
            Image.asset(
              'assets/illus/$illus',
              width: 160,
              height: 120,
              // 320×240 源按 160×120 逻辑像素显示，高 dpi 屏 1:1 采样不发虚
              filterQuality: FilterQuality.high,
            ),
            const SizedBox(height: 20),
            Text(title,
                style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!,
                  style: theme.textTheme.bodySmall,
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
