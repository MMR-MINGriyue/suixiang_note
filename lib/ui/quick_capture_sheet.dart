import 'dart:async';

import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../theme/tokens.dart';

/// 速记捕捉页：模态全屏，自动落库（500ms 防抖），无保存按钮（PRD §4.1）
class QuickCaptureSheet extends StatefulWidget {
  final AppDatabase db;
  const QuickCaptureSheet({super.key, required this.db});

  /// 统一入口：showModalBottomSheet 全屏弹层
  static Future<void> open(BuildContext context, AppDatabase db) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QuickCaptureSheet(db: db),
    );
  }

  @override
  State<QuickCaptureSheet> createState() => _QuickCaptureSheetState();
}

class _QuickCaptureSheetState extends State<QuickCaptureSheet> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  int? _savedId; // 首次落库后持有，后续防抖更新
  int _wordCount = 0;
  DateTime? _savedAt;

  @override
  void initState() {
    super.initState();
    // 进场即聚焦：目标「点 FAB → 可输入 ≤600ms」
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  void _onChanged(String text) {
    setState(() => _wordCount = text.replaceAll(RegExp(r'\s'), '').length);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final id = await widget.db.saveDraft(id: _savedId, content: text);
      if (!mounted) return;
      if (id > 0) {
        setState(() {
          _savedId = id;
          _savedAt = DateTime.now();
        });
      } else if (id == -1 && _savedId != null) {
        // 内容被清空：草稿已硬删，回到未落库态
        setState(() {
          _savedId = null;
          _savedAt = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(T.rSheet)),
        ),
        padding: const EdgeInsets.fromLTRB(T.pagePad, 12, T.pagePad, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 顶部状态行：标题 + 自动保存指示
            Row(children: [
              Text('随想速记', style: theme.textTheme.titleMedium),
              const Spacer(),
              _SavedIndicator(savedAt: _savedAt),
            ]),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              focusNode: _focus,
              maxLines: null,
              minLines: 6,
              onChanged: _onChanged,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: '第一个念头，从一颗水滴开始…',
                hintStyle: const TextStyle(color: T.inkTertiary),
                border: InputBorder.none,
              ),
              style: theme.textTheme.bodyLarge,
            ),
            Row(children: [
              Text('$_wordCount 字',
                  style: const TextStyle(color: T.inkTertiary, fontSize: 12)),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('完成'),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

/// 自动保存状态指示：未落库=隐藏；已落库=「已自动保存」
class _SavedIndicator extends StatelessWidget {
  final DateTime? savedAt;
  const _SavedIndicator({required this.savedAt});

  @override
  Widget build(BuildContext context) {
    if (savedAt == null) return const SizedBox.shrink();
    return Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.check_circle_outline, size: 14, color: T.stageDone),
      const SizedBox(width: 4),
      Text('已自动保存',
          style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).brightness == Brightness.dark
                  ? T.stageDone
                  : const Color(0xFF1E8A67))),
    ]);
  }
}
