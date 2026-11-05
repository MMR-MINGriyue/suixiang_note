import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/markdown_edit.dart';
import '../../theme/tokens.dart';

/// 编辑工具条：一排格式按钮 + 撤销重做。
///
/// 排布取舍：
/// - 横向滚动而不是换行铺满。手机上键盘弹起后可用高度只剩一半，
///   工具条占两行会挤掉正文；一行横滚能用手指滑，也不会永远显示「更多」。
/// - 撤销/重做固定在左侧不参与滚动——这两个是最常用的，滚走了就没意义。
/// - 每个按钮 40×40（比 44 略小）：工具条是高频轻点区域，不是主要操作区，
///   40 已够准，44 会让 7 个格式在 375 宽屏上排不完。
class EditToolbar extends StatelessWidget {
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final void Function(MdFormat format) onFormat;
  final VoidCallback onFindReplace;
  final VoidCallback onInsertTime;
  final bool previewing;

  const EditToolbar({
    super.key,
    required this.onUndo,
    required this.onRedo,
    required this.onFormat,
    required this.onFindReplace,
    required this.onInsertTime,
    this.previewing = false,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: dark ? T.darkCard : T.paperCard,
        border: Border(
          top: BorderSide(color: T.ink3(context).withValues(alpha: 0.18)),
        ),
      ),
      child: Row(children: [
        _IconBtn(
          icon: Icons.undo,
          tooltip: '撤销',
          onTap: onUndo,
        ),
        _IconBtn(
          icon: Icons.redo,
          tooltip: '重做',
          onTap: onRedo,
        ),
        Container(
          width: 1,
          height: 20,
          color: T.inkTertiary.withValues(alpha: 0.25),
        ),
        Expanded(
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            children: [
              for (final f in kFormats)
                _FormatBtn(
                  label: f.label,
                  tooltip: _tooltipOf(f.id),
                  onTap: previewing ? null : () => onFormat(f),
                  isCode: f.id == 'code',
                ),
              Container(
                width: 1,
                height: 20,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                color: T.inkTertiary.withValues(alpha: 0.25),
              ),
              _IconBtn(
                icon: Icons.horizontal_rule,
                tooltip: '分割线',
                onTap: previewing
                    ? null
                    : () => onFormat(const MdFormat(
                        id: 'hr', label: 'hr', placeholder: '---')),
              ),
              _IconBtn(
                icon: Icons.schedule,
                tooltip: '插入当前时间',
                onTap: previewing ? null : onInsertTime,
              ),
              _IconBtn(
                icon: Icons.find_replace,
                tooltip: '查找替换',
                onTap: onFindReplace,
              ),
            ],
          ),
        ),
      ]),
    );
  }

  static String _tooltipOf(String id) => switch (id) {
        'bold' => '加粗 **文字**',
        'italic' => '斜体 *文字*',
        'strike' => '删除线 ~~文字~~',
        'code' => '代码 `文字`',
        'h1' => '标题（再点切换 H2/H3/取消）',
        'bullet' => '列表（再点切换 有序/待办）',
        'quote' => '引用',
        _ => id,
      };
}

class _FormatBtn extends StatelessWidget {
  final String label;
  final String tooltip;
  final VoidCallback? onTap;
  final bool isCode;
  const _FormatBtn({
    required this.label,
    required this.tooltip,
    required this.onTap,
    this.isCode = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: isCode ? 11 : 15,
                fontWeight: isCode ? FontWeight.w600 : FontWeight.w700,
                fontFamily: isCode ? 'monospace' : null,
                color: enabled
                    ? T.ink1(context)
                    : T.ink3(context).withValues(alpha: 0.4),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  const _IconBtn({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: enabled ? () {
          HapticFeedback.selectionClick();
          onTap!();
        } : null,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 40,
          height: 48,
          child: Icon(
            icon,
            size: 19,
            color: enabled
                ? T.ink2(context)
                : T.ink3(context).withValues(alpha: 0.35),
          ),
        ),
      ),
    );
  }
}
