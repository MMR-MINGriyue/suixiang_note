import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/app_signals.dart';
import 'core/launch_intent.dart';
import 'core/pinyin_search.dart';
import 'core/reminder_service.dart';
import 'theme/tokens.dart';
import 'ui/detail_page.dart';
import 'ui/folders_page.dart';
import 'ui/home_page.dart';
import 'ui/profile_page.dart';
import 'ui/quick_capture_sheet.dart';
import 'ui/widgets/drop_badge.dart';

/// 随想随记 — 本地优先的轻量灵感管理
/// v1.5：外部入口（桌面小部件 / 通知栏常驻 / 系统分享 / 深链）直达速记
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 拼音首字母表：21KB，一次读入常驻内存。失败不阻塞启动（搜索退化为字面匹配）
  await PinyinSearch.ensureLoaded();
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

/// 全局单例与主题状态在 core/app_signals.dart（架构评审 C1：
/// folders_page / profile_page / home_page 不再反向 import main.dart）。
/// （架构复审观察-1：原 launchIntentNotifier 全库无订阅方，已删。）

/// 「跳到归档视图」请求信号：长按图标选「归档」快捷方式时，
/// 原生侧推一个 tick，首页监听后把过滤切到归档（不用重建首页、不用路由栈）。
/// 定义在 core/app_signals.dart（架构评审 C1：UI 不得反向 import main.dart）。

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

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _index = 0;
  static const _launchChannel = MethodChannel('suixiang/launch');
  // 架构复审 P1-2：首帧 postFrameCallback 与 resumed 几乎同时触发对账，
  // 不加互斥会同批 due 被读两次、弹两条一样的 SnackBar。
  bool _reconciling = false;
  // 全量重排只在冷启动做一次（AlarmManager 排程在进程外，重装/清数据会丢；
  // 提醒的写变更都走单条 schedule/cancel，无需每次回前台重排全量）。
  bool _didInitialReschedule = false;
  // 架构复审观察-4：连点通知/深链会叠两个 DetailPage / 速记面板。
  bool _navigating = false;
  // 架构复审 P1-3：页面列表只建一次，切 Tab 不销毁首页的搜索/筛选/多选状态。
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pages = <Widget>[
      HomePage(db: appDb), // Tab 0 随记
      const FoldersPage(), // Tab 1 文件夹（M4 已落）
      const ProfilePage(), // Tab 2 我的（M6 已落 v1.0 收敛版）
    ];
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
        } else if (parsed.thoughtId != null) {
          _handleOpenThought(parsed.thoughtId!);
        } else if (parsed.isCapture || action == 'capture') {
          _handleCapture(text ?? parsed.text);
        }
      }
      return null;
    });
    // 冷启动意图与提醒对账都等首帧（Navigator / Overlay 就绪后）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleInitialLaunch();
      _reconcileReminders();
    });
    // 架构复审 P1-4：告知原生「handler 已就绪」，原生侧此后才补推残留 pending
    _launchChannel.invokeMethod('notifyReady').catchError((_) => false);
  }

  /// 冷启动意图分发（原 initState 里的三分支，收敛成一个方法）
  void _handleInitialLaunch() {
    final launch = widget.initialLaunch;
    if (launch.isCapture) {
      _handleCapture(launch.text);
    } else if (launch.isArchived) {
      setState(() => _index = 0);
      archivedRequestTicker.value++;
    } else if (launch.thoughtId != null) {
      // 从提醒通知点进来：suixiang://thought/<id> 直达该条随记
      _handleOpenThought(launch.thoughtId!);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _launchChannel.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 每次回前台都对账一次：这是「用户不开通知权限也不漏提醒」的兜底路径
    if (state == AppLifecycleState.resumed) {
      _reconcileReminders();
    }
  }

  /// 提醒对账：把已过期但未通知的提醒捞出来，用应用内弹层提示。
  ///
  /// 架构复审 P1-2：加 [_reconciling] 互斥（首帧与 resumed 并发只跑一个）；
  /// 全量重排收敛为冷启动首帧一次（[_didInitialReschedule]）。
  Future<void> _reconcileReminders() async {
    if (!mounted || _reconciling) return;
    _reconciling = true;
    try {
      if (!_didInitialReschedule) {
        _didInitialReschedule = true;
        if (ReminderService.supported) {
          await ReminderService.rescheduleAll(appDb);
        }
      }
      final due = await ReminderService.reconcile(appDb);
      if (due.isEmpty || !mounted) return;
      setState(() => _index = 0);
      final first = due.first;
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(SnackBar(
        content: Text(
          due.length == 1
              ? '提醒：${first.headline}'
              : '有 ${due.length} 条提醒到点了（第一条：${first.headline}）',
        ),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: '查看',
          onPressed: () => _handleOpenThought(first.thought.id),
        ),
      ));
    } finally {
      _reconciling = false;
    }
  }

  Future<void> _handleOpenThought(int thoughtId) async {
    if (!mounted || _navigating) return;
    final thought = await appDb.getThought(thoughtId);
    if (thought == null || !mounted || _navigating) return;
    _navigating = true;
    try {
      setState(() => _index = 0);
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DetailPage(db: appDb, thought: thought)),
      );
    } finally {
      _navigating = false;
    }
  }

  Future<void> _handleCapture(String? text) async {
    if (!mounted || _navigating) return;
    _navigating = true;
    try {
      // 从外部进来时先回到「随记」Tab，速记面板关掉后落在列表而不是设置页
      setState(() => _index = 0);
      await QuickCaptureSheet.open(context, appDb, initialText: text);
    } finally {
      _navigating = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 架构复审 P1-3：IndexedStack 保活三个 Tab——切走再切回来，
      // 首页的搜索词 / 筛选 / 多选与滚动位置都在，不重建不重订
      body: IndexedStack(index: _index.clamp(0, _pages.length - 1), children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        destinations: const [
          // 图标规范①：导航栏选中态 filled / 未选中 outlined（三组成对）。
          // 「随记」的品牌水滴：灵感态轮廓即未选中、实心水滴即选中，
          // 与列表里的 DropBadge 三态语言同源。
          NavigationDestination(
            icon: Icon(DropBadgeIcons.dropOutline),
            selectedIcon: Icon(Icons.water_drop),
            label: '随记',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder),
            label: '文件夹',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '我的',
          ),
        ],
        onDestinationSelected: (i) => setState(() => _index = i),
      ),
    );
  }
}
