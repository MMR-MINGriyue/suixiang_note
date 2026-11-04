import '../data/app_database.dart';
import 'package:flutter/painting.dart' show Color;

/// 统一的字数口径：去空白后的字符数。
///
/// 抽出来的理由（架构评审 B1）：同一条正则原来在
/// saveDraft / quick_capture_sheet / detail_page 各写一份，
/// 改口径（比如想把英文按词算）要同步三处。
int countWords(String text) => text.replaceAll(RegExp(r'\s'), '').length;

/// 数据库里的 `#RRGGBB` 字符串 → Color。
///
/// 抽出来的理由（架构评审 B3）：`replaceFirst('#')` + tryParse 原来散在
/// 10+ 处，一部分用 `tryParse` 有兜底、一部分直接 `int.parse`（脏数据
/// 直接崩）；抽掉后统一走 tryParse + fallback。
/// 从 hexToColor（widgets/color_palette.dart）挪过来：纯函数放 core，
/// UI 组件反向引用纯函数层才不会成环。
Color parseHexColor(String hex, {Color fallback = const Color(0xFF4C6FFF)}) {
  final c = int.tryParse(hex.replaceFirst('#', '0xFF'));
  return c != null ? Color(c) : fallback;
}

/// 三态推进的纯函数集合。
///
/// 抽出来的理由（架构评审 B2）：`nextStage` 逻辑原来在
/// app_database.advanceStage 与 detail_page._nextStageName 各写一份，
/// 加一条自定义阶段就会出现两处口径不一致。
/// 这里只做查表与格式化，不碰数据库，方便单测直接覆盖。

/// 按 position 升序取下一态；当前态找不到时回到第一态。
/// [stages] 必须已按 position 升序（[AppDatabase.watchStages] 保证）。
Stage? nextStageOf(List<Stage> stages, int currentStageId) {
  if (stages.isEmpty) return null;
  final idx = stages.indexWhere((s) => s.id == currentStageId);
  if (idx < 0) return stages.first;
  return stages[(idx + 1) % stages.length];
}

/// 按 id 找阶段；找不到回退第一态（宁可显示「灵感」也不要 null 崩界面）
Stage? stageById(List<Stage> stages, int stageId) {
  if (stages.isEmpty) return null;
  for (final s in stages) {
    if (s.id == stageId) return s;
  }
  return stages.first;
}

/// 上一态（长按菜单里「退回」用；第一态的上一步是最后一态，与循环推进对称）
Stage? prevStageOf(List<Stage> stages, int currentStageId) {
  if (stages.isEmpty) return null;
  final idx = stages.indexWhere((s) => s.id == currentStageId);
  if (idx < 0) return stages.first;
  final prev = (idx - 1 + stages.length) % stages.length;
  return stages[prev];
}

/// 完成时间的人话描述：今天完成 / 昨天完成 / N 天前完成 / 2026/03/04 完成。
///
/// `completedAt` 这个字段从 v1.0 就在写，但界面从来没用过——完成了多久
/// 恰恰是「推进」这条主线上用户唯一想回头看的信息。
String completedLabel(int? completedAt, {DateTime? now}) {
  if (completedAt == null) return '';
  final at = DateTime.fromMillisecondsSinceEpoch(completedAt);
  final ref = now ?? DateTime.now();
  final today = DateTime(ref.year, ref.month, ref.day);
  final day = DateTime(at.year, at.month, at.day);
  final diff = today.difference(day).inDays;
  if (diff <= 0) return '今天完成';
  if (diff == 1) return '昨天完成';
  if (diff < 30) return '$diff 天前完成';
  final mm = at.month.toString().padLeft(2, '0');
  final dd = at.day.toString().padLeft(2, '0');
  return '${at.year}/$mm/$dd 完成';
}

/// 同 [completedLabel]，但不带「完成」二字——用在已经有「完成」上下文的行内
String shortAgeLabel(int? ts, {DateTime? now}) {
  if (ts == null) return '';
  final at = DateTime.fromMillisecondsSinceEpoch(ts);
  final ref = now ?? DateTime.now();
  final today = DateTime(ref.year, ref.month, ref.day);
  final day = DateTime(at.year, at.month, at.day);
  final diff = today.difference(day).inDays;
  if (diff <= 0) return '今天';
  if (diff == 1) return '昨天';
  if (diff < 30) return '$diff 天前';
  final mm = at.month.toString().padLeft(2, '0');
  final dd = at.day.toString().padLeft(2, '0');
  return '${at.year}/$mm/$dd';
}

/// 停在当前这一步多久了（「卡了几天」）。
///
/// 只对「推进中」有意义：灵感躺着是正常的，已完成躺着是应该的，
/// 只有「推进中」停住了才是需要被看见的信号。所以 [kind] 不是
/// in_progress 时返回空串，界面就不会多出一行噪音。
///
/// 阈值取 3 天：一天内换态是正常节奏，两天可能只是周末，
/// 三天还没动，说明这件事实际上已经停了。
String stagnationLabel(int? stageChangedAt, String kind, {DateTime? now}) {
  if (kind != 'in_progress' || stageChangedAt == null) return '';
  final ref = now ?? DateTime.now();
  final at = DateTime.fromMillisecondsSinceEpoch(stageChangedAt);
  final days = DateTime(ref.year, ref.month, ref.day)
      .difference(DateTime(at.year, at.month, at.day))
      .inDays;
  if (days < 3) return '';
  return '停在这里 $days 天';
}
