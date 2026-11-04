import 'package:flutter/material.dart';

import '../data/app_database.dart';

/// 全局单例与跨页信号总线（架构评审 C1）。
///
/// 放在 core 而不是 main.dart 的理由：folders_page / profile_page / home_page
/// 都要用 appDb 与主题状态，若定义在 main.dart，UI 就要
/// `import '../main.dart'`——数据/展示层反向依赖入口文件，改 main 的任何
/// 东西都可能连坐整条 UI 链。挪到 core 后依赖方向变成 main → core ← ui，
/// 单向干净。

/// 全局数据库单例（单进程本地 App，无需依赖注入框架）
final appDb = AppDatabase();

/// 全局主题状态（ValueNotifier 让「我的」页切主题免重启即时生效）
final themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);

/// 长按图标「归档」快捷方式唤起时，首页切到归档视图的广播。
/// 首页监听它而不重建（避免丢搜索/筛选上下文）。
final archivedRequestTicker = ValueNotifier<int>(0);
