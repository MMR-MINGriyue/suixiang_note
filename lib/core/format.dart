import '../data/app_database.dart';

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
