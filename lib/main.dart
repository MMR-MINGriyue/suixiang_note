import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/launch_intent.dart';
import 'data/app_database.dart';
import 'theme/tokens.dart';
import 'ui/folders_page.dart';
import 'ui/home_page.dart';
import 'ui/profile_page.dart';
import 'ui/quick_capture_sheet.dart';

/// 随想随记 — 本地优先的轻量灵感管理
/// v1.5：外部入口（桌面小部件 / 通知栏常驻 / 系统分享 / 深链）直达速记
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final themeMode = switch (prefs.getString('theme_mode') ?? 'system') {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
  themeModeNotifier.value = themeMode;
  // 首帧前取一次启动意图：外部点「记一条」进来时，启动就带着 capture 指令
  final launch = await LaunchIntent.readInitial();
  runApp(SuixiangApp(initialThemeMode: themeMode, initialLaunch: launch));
}

/// 全局单例 db（单进程本地 App，无需依赖注入框架）
final appDb = AppDatabase();

/// 全局主题状态（ValueNotifier 让「我的」页切主题免重启即时生效）
final themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);

/// 外部入口二次唤起（应用已在后台时点小部件/通知栏）广播：
/// AppShell 订阅它，收到就弹速记，不重建整个 App。
final launchIntentNotifier = ValueNotifier<LaunchIntent>(LaunchIntent.none);

/// 「跳到归档视图」请求信号：长按图标选「归档」快捷方式时，
/// 原生侧推一个 tick，首页监听后把过滤切到归档（不用重建首页、不用路由栈）。
final archivedRequestTicker = ValueNotifier<int>(0);

class SuixiangApp extends StatelessWidget {
  final ThemeMode initialThemeMode;
  final LaunchIntent initialLaunch;
  const SuixiangApp(
      {super.key, required this.initialThemeMode, this.initialLaunch = LaunchIntent.none});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, mode, child) => MaterialApp(
        title: '随想随记',
        theme: buildLightTheme(),
        darkTheme: buildDarkTheme(),
        themeMode: mode,
        home: AppShell(initialLaunch: initialLaunch),
      ),
    );
  }
}

/// App 壳：底部导航 3 Tab + 外部入口处理
class AppShell extends StatefulWidget {
  final LaunchIntent initialLaunch;
  const AppShell({super.key, this.initialLaunch = LaunchIntent.none});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  static const _launchChannel = MethodChannel('suixiang/launch');

  @override
  void initState() {
    super.initState();
    // 冷启动带着 capture：等首帧后再弹，否则 Navigator 还没有 Overlay
    if (widget.initialLaunch.isCapture) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleCapture(widget.initialLaunch.text);
      });
    } else if (widget.initialLaunch.isArchived) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() => _index = 0);
        archivedRequestTicker.value++;
      });
    }
    // 热启动（应用在后台时被唤起）：原生侧推 onIntent 过来
    _launchChannel.setMethodCallHandler((call) async {
      if (call.method == 'onIntent') {
        final args = (call.arguments as Map?) ?? const {};
        final text = args['text'] as String?;
        final uri = args['uri'] as String?;
        final action = args['action'] as String?;
        final parsed =
            uri != null ? LaunchIntent.parseUri(uri) : LaunchIntent.none;
        if (parsed.isArchived || action == 'archived') {
          if (!mounted) return null;
          setState(() => _index = 0);
          archivedRequestTicker.value++;
        } else if (parsed.isCapture || action == 'capture') {
          _handleCapture(text ?? parsed.text);
        }
      }
      return null;
    });
  }

  Future<void> _handleCapture(String? text) async {
    if (!mounted) return;
    // 从外部进来时先回到「随记」Tab，速记面板关掉后落在列表而不是设置页
    setState(() => _index = 0);
    await QuickCaptureSheet.open(context, appDb, initialText: text);
  }

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
