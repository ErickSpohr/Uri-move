import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/api.dart';
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
          builder: (context, child) => _SlowConnectionOverlay(
            child: child ?? const SizedBox.shrink(),
          ),
          home: const SplashScreen(),
        ),
      ),
    );
  }
}

/// Faixa exibida sobre todas as telas enquanto alguma requisição excede
/// [ApiClient.slowThreshold] — tipicamente a retomada do servidor gratuito.
class _SlowConnectionOverlay extends StatelessWidget {
  const _SlowConnectionOverlay({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        ValueListenableBuilder<int>(
          valueListenable: ApiClient.slowRequests,
          builder: (context, slowCount, _) {
            if (slowCount == 0) {
              return const SizedBox.shrink();
            }
            final colors = Theme.of(context).colorScheme;
            return Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Material(
                  color: colors.inverseSurface,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.onInverseSurface,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Conectando ao servidor… isso pode levar até 1 minuto.',
                            style: TextStyle(color: colors.onInverseSurface),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
