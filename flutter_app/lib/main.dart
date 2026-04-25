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
          title: 'Wire CRM',
          debugShowCheckedModeBanner: false,
          theme: const CupertinoThemeData(
            primaryColor: Color(0xFF015557),
            scaffoldBackgroundColor: Color(0xFFF5F7F8),
            barBackgroundColor: Color(0xFFF5F7F8),
          ),
          home: controller.isReady
              ? (controller.isAuthenticated
                    ? HomeShell(controller: controller)
                    : LoginScreen(controller: controller))
              : const SplashScreen(),
        );
      },
    );
  }
}
