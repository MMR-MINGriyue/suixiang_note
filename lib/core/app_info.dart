/// 应用元信息（关于页专用）
///
/// 为什么不用 package_info_plus：为了一个版本号字符串引一个跨平台插件，
/// 要在 Android/iOS/Windows 三套原生侧各带一份实现，收益不成比例。
/// 这里用一个常量，由 CI 校验它与 pubspec.yaml 的 version 一致——
/// 之前关于页写死「v1.0」而实际已经是 1.8.0，就是因为两处各写各的。
library;

/// 必须与 pubspec.yaml 的 version 字段完全相同（含 +buildNumber）。
const String kAppVersion = '2.6.1+19';

/// 给用户看的短版本号（去掉 build number）
String get kAppVersionShort => kAppVersion.split('+').first;

/// 数据库文件名（drift_flutter 的 `driftDatabase(name: ...)` 会存成 `名字.sqlite`）
const String kDatabaseName = 'suixiang_note';

/// 备份子目录名（在「文档」目录下）
const String kBackupFolderName = 'suixiang_note_backups';
