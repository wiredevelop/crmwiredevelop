import 'package:flutter/cupertino.dart';

import 'app_controller.dart';
import 'screens.dart';
import 'widgets/ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final controller = AppController();
  await controller.initialize();

  runApp(WireCrmApp(controller: controller));
}

class WireCrmApp extends StatelessWidget {
  const WireCrmApp({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return CupertinoApp(
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
          home: controller.isReady
              ? (controller.isAuthenticated
                    ? (controller.mustChangePassword
                          ? ForcedPasswordChangeScreen(controller: controller)
                          : HomeShell(controller: controller))
                    : LoginScreen(controller: controller))
              : const SplashScreen(),
        );
      },
    );
  }
}
