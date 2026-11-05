import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/tokens.dart';

/// 写操作反馈的公共收敛点（UI 复审 P0-5）。
///
/// 首页 `_advance` 从 v1.9 起就用「触觉 + SnackBar 状态迁移 + 撤回」三件套，
/// 但 v1.6/v2.x 新增的面板里有多处直接写库后静默 pop/返回：
/// 用户点了「设定提醒」「取消关联」「彻底删除」，界面一闪，不知道有没有生效。
/// 这里把反馈与危险确认收敛成两枚纯静态方法，避免每个页面各写一遍
/// （也不再出现「有的删除有确认弹窗、有的没有」的规格漂移）。
class AppFeedback {
  const AppFeedback._();

  /// 成功反馈：一次轻触觉 + 一条短 SnackBar。
  ///
  /// 触觉用 selectionClick 而不是 mediumImpact——写库确认是「落定」，
  /// 不是「推进状态」那种需要强调的动作。
  static void success(BuildContext context, String message,
      {Duration duration = const Duration(seconds: 2)}) {
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      duration: duration,
      behavior: SnackBarBehavior.floating,
    ));
  }

  /// 危险且不可撤销的操作确认弹窗（统一规格：危险色确认按钮）。
  ///
  /// 返回 true 才执行删除；取消/点遮罩都是 false。文案里必须自己写清
  /// 「不可撤销」，这里不代劳——不同操作的影响面不同（删单条 vs 清空回收站）。
  static Future<bool> confirmDanger(
    BuildContext context, {
    required String title,
    required String content,
    String confirmLabel = '删除',
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: T.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return ok == true;
  }
}
