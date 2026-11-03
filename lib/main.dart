import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/app_database.dart';
import 'theme/tokens.dart';
import 'ui/folders_page.dart';
import 'ui/home_page.dart';
import 'ui/profile_page.dart';

/// 随想随记 — 本地优先的轻量灵感管理
/// v1.0：3 Tab（随记/文件夹/我的），文件夹与我的页随 M4/M6 里程碑填充
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final themeMode = switch (prefs.getString('theme_mode') ?? 'system') {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
  themeModeNotifier.value = themeMode;
  runApp(SuixiangApp(initialThemeMode: themeMode));
}

/// 全局单例 db（单进程本地 App，无需依赖注入框架）
final appDb = AppDatabase();

/// 全局主题状态（ValueNotifier 让「我的」页切主题免重启即时生效）
final themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);

class SuixiangApp extends StatelessWidget {
  final ThemeMode initialThemeMode;
  const SuixiangApp({super.key, required this.initialThemeMode});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, mode, child) => MaterialApp(
        title: '随想随记',
        theme: buildLightTheme(),
        darkTheme: buildDarkTheme(),
        themeMode: mode,
        home: const AppShell(),
      ),
    );
  }
}

/// App 壳：底部导航 3 Tab
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomePage(db: appDb), // Tab 0 随记
      const FoldersPage(), // Tab 1 文件夹（M4 已落）
      const ProfilePage(), // Tab 2 我的（M6 已落 v1.0 收敛版）
    ];
    return Scaffold(
      body: pages[_index.clamp(0, pages.length - 1)],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.water_drop_outlined), label: '随记'),
          NavigationDestination(icon: Icon(Icons.folder_outlined), label: '文件夹'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: '我的'),
        ],
        onDestinationSelected: (i) => setState(() => _index = i),
      ),
    );
  }
}
