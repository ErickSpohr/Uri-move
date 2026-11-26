import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'env_config.dart';
import 'screens/splash_screen.dart';
import 'state/auth_controller.dart';
import 'state/theme_controller.dart';

void main() {
  EnvConfig.validate();
  runApp(const URIMoveApp());
}

class URIMoveApp extends StatelessWidget {
  const URIMoveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthController()),
        ChangeNotifierProvider(create: (_) => ThemeController()..load()),
      ],
      child: Consumer<ThemeController>(
        builder: (context, appearance, _) => MaterialApp(
          title: 'URI Move',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: appearance.themeMode,
          home: const SplashScreen(),
        ),
      ),
    );
  }
}
