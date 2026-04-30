import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/cupertino.dart';
import 'package:home_widget/home_widget.dart';

import 'app_controller.dart';
import 'services/notification_service.dart';
import 'screens.dart';
import 'services/widget_sync_service.dart';
import 'widgets/ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await WidgetSyncService.configure();
  await NotificationService.instance.initialize();

  final controller = AppController();
  await controller.initialize();

  runApp(WireCrmApp(controller: controller));
}

class WireCrmApp extends StatefulWidget {
  const WireCrmApp({super.key, required this.controller});

  final AppController controller;

  @override
  State<WireCrmApp> createState() => _WireCrmAppState();
}

class _WireCrmAppState extends State<WireCrmApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  StreamSubscription<Uri?>? _widgetClickSubscription;
  StreamSubscription<Uri>? _notificationLaunchSubscription;
  int _lastHandledWalletReturnVersion = 0;

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();
    widget.controller.addListener(_handleControllerChange);
    _setupDeepLinks();
    _setupWidgetLaunches();
    _setupNotificationLaunches();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _widgetClickSubscription?.cancel();
    _notificationLaunchSubscription?.cancel();
    widget.controller.removeListener(_handleControllerChange);
    super.dispose();
  }

  Future<void> _setupDeepLinks() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        widget.controller.handleIncomingUri(initialUri);
      }
    } catch (_) {}

    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      widget.controller.handleIncomingUri(uri);
    }, onError: (_) {});
  }

  Future<void> _setupWidgetLaunches() async {
    try {
      final initialUri = await HomeWidget.initiallyLaunchedFromHomeWidget();
      if (initialUri != null) {
        widget.controller.handleIncomingUri(initialUri);
      }
    } catch (_) {}

    _widgetClickSubscription = HomeWidget.widgetClicked.listen((uri) {
      if (uri != null) {
        widget.controller.handleIncomingUri(uri);
      }
    }, onError: (_) {});
  }

  void _setupNotificationLaunches() {
    final initialUri = NotificationService.instance.consumeInitialUri();
    if (initialUri != null) {
      widget.controller.handleIncomingUri(initialUri);
    }

    _notificationLaunchSubscription = NotificationService.instance.launchStream
        .listen((uri) {
          widget.controller.handleIncomingUri(uri);
        }, onError: (_) {});
  }

  void _handleControllerChange() {
    if (!mounted) {
      return;
    }

    if (!widget.controller.isReady ||
        !widget.controller.isAuthenticated ||
        widget.controller.mustChangePassword) {
      return;
    }

    final version = widget.controller.walletCheckoutReturnVersion;
    final pending = widget.controller.pendingWalletCheckoutReturn;
    if (pending == null || version == _lastHandledWalletReturnVersion) {
      return;
    }

    _lastHandledWalletReturnVersion = version;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final paymentReturn = widget.controller
          .consumePendingWalletCheckoutReturn();
      final navigator = _navigatorKey.currentState;

      if (paymentReturn == null || navigator == null) {
        return;
      }

      navigator.push(
        CupertinoPageRoute(
          builder: (context) => ClientWalletScreen(
            controller: widget.controller,
            paymentReturn: paymentReturn,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return CupertinoApp(
          navigatorKey: _navigatorKey,
          title: 'WireDevelop',
          debugShowCheckedModeBanner: false,
          theme: const CupertinoThemeData(
            primaryColor: CupertinoColors.white,
            scaffoldBackgroundColor: kBrandColor,
            barBackgroundColor: Color(0x1AFFFFFF),
            textTheme: CupertinoTextThemeData(
              navTitleTextStyle: TextStyle(
                color: CupertinoColors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
              navLargeTitleTextStyle: TextStyle(
                color: CupertinoColors.white,
                fontSize: 34,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          home: widget.controller.isReady
              ? (widget.controller.isAuthenticated
                    ? (widget.controller.mustChangePassword
                          ? ForcedPasswordChangeScreen(
                              controller: widget.controller,
                            )
                          : HomeShell(controller: widget.controller))
                    : LoginScreen(controller: widget.controller))
              : const SplashScreen(),
        );
      },
    );
  }
}
