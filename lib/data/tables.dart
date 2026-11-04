import 'package:drift/drift.dart';

/// 随想随记 数据层表定义 —— 对齐 PRD §6.2（`D:\workspace\随想随记-功能设计.md:487-605`）
/// v1.0 范围：8 表全建（含 P1 的 reminders/attachments，避免未来迁移）；
/// FTS5 虚表按评审结论暂缓，v1.0 搜索走 LIKE。

/// 文件夹表（P0-4）
class Folders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()(); // ≤20 字，DAO 层校验
  TextColumn get icon => text().withDefault(const Constant('folder'))();
  TextColumn get color => text().withDefault(const Constant('#4C6FFF'))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()(); // 软删；随记 folderId 置 NULL 由 DAO 处理
}

/// 阶段表：系统三态（灵感/推进中/已完成）+ 未来自定义阶段
class Stages extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get kind => text()(); // inspiration / in_progress / done / custom
  TextColumn get color => text()();
  RealColumn get position => real()(); // 排序键，插入取中值
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))(); // 内置三态禁删禁改
  IntColumn get createdAt => integer()();
}

/// 随记主表（P0 核心，16 字段对齐 PRD）
class Thoughts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()(); // 跨备份/导出稳定标识（v4 随机）
  TextColumn get title => text().withDefault(const Constant(''))(); // 首行派生
  TextColumn get content => text().withDefault(const Constant(''))();
  IntColumn get folderId => integer().nullable().references(Folders, #id)(); // 空=收件箱
  IntColumn get stageId => integer().references(Stages, #id)();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  IntColumn get pinnedAt => integer().nullable()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  TextColumn get source => text().withDefault(const Constant('app'))();
  IntColumn get wordCount => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()(); // 冲突判定基准
  IntColumn get completedAt => integer().nullable()(); // 进入「已完成」时刻
  // 进入当前阶段的时刻（v3）。updatedAt 每次编辑都会变，问不出「这件事
  // 在推进中卡了几天」；这个字段专门回答那个问题。
  IntColumn get stageChangedAt => integer().nullable()();
  IntColumn get deletedAt => integer().nullable()(); // 软删；非空=回收站
}

/// 标签表（表先建，UI v1.1 再暴露 —— PM 评审结论）
class Tags extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()(); // ≤20 字，重名 NOCASE 拦截在 DAO
  TextColumn get color => text().withDefault(const Constant('#4C6FFF'))();
  IntColumn get sortWeight => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get deletedAt => integer().nullable()();
}

/// 随记×标签 多对多
class ThoughtTags extends Table {
  IntColumn get thoughtId => integer().references(Thoughts, #id)();
  IntColumn get tagId => integer().references(Tags, #id)();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {thoughtId, tagId};
}

/// 提醒表（P1-4，暂缓 UI）
class Reminders extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get thoughtId => integer().references(Thoughts, #id)();
  IntColumn get remindAt => integer()();
  TextColumn get repeatRule => text().withDefault(const Constant('once'))();
  IntColumn get repeatInterval => integer().nullable()();
  TextColumn get repeatUnit => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('active'))();
  IntColumn get lastFiredAt => integer().nullable()();
  IntColumn get createdAt => integer()();
}

/// 附件表（P1，语音/图片）
class Attachments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get thoughtId => integer().references(Thoughts, #id)();
  TextColumn get type => text()(); // audio / image
  TextColumn get filePath => text()();
  IntColumn get durationMs => integer().nullable()();
  IntColumn get createdAt => integer()();
}

/// 设置 KV 全表（19 键随 PRD，UI 只暴露 9 项 —— PM/UX 收敛结论）
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text().nullable()();

  @override
  Set<Column> get primaryKey => {key};
}

/// 随记之间的关联（v4）。
///
/// 为什么不用标签代替：标签是「一堆东西的共同属性」，关联是「这两条之间的
/// 具体关系」，两者的检索方向相反——标签回答「还有哪些也是X」，关联回答
/// 「这条跟哪条有关、怎么有关」。做成标签就无法表达方向与关系类型。
///
/// 为什么不用文件夹层级代替：文件夹是一棵树，一条只能在一个文件夹里；
/// 而「这件事同时是 A 的后续和 B 的前提」是很常见的，树装不下。
class ThoughtLinks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get fromId => integer().references(Thoughts, #id)();
  IntColumn get toId => integer().references(Thoughts, #id)();
  // related 相关 / depends 依赖（from 依赖 to）/ parent 从属（from 属于 to）
  TextColumn get kind => text().withDefault(const Constant('related'))();
  IntColumn get createdAt => integer()();
  IntColumn get deletedAt => integer().nullable()();

  @override
  List<String> get customConstraints => [
        'UNIQUE (from_id, to_id, kind)',
        'CHECK (from_id <> to_id)',
      ];
}
