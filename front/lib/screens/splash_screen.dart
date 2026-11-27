import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../widgets/loading_indicator.dart';
import '../state/auth_controller.dart';
import '../widgets/common.dart';
import 'login_screen.dart';
import 'main_shell.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final auth = context.read<AuthController>();
    if (_failed) setState(() => _failed = false);
    if (!auth.ready) {
      await auth.restore();
    }
    if (!mounted) {
      return;
    }
    if (auth.restoreFailed) {
      setState(() => _failed = true);
      return;
    }
    // Primeiro acesso no aparelho (sem login salvo): apresentação antes do login.
    if (!auth.isAuthenticated && !await OnboardingScreen.wasSeen()) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (onboardingContext) => OnboardingScreen(
            onDone: () => Navigator.of(onboardingContext).pushReplacement(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            ),
          ),
        ),
      );
      return;
    }
    if (!mounted) return;
    final target = auth.isAuthenticated
        ? const MainShell()
        : const LoginScreen();
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (_) => target));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppLogo(height: 180),
            const SizedBox(height: 12),
            Text(
              'Caronas entre universitários da URI',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 28),
            if (_failed)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    const Text(
                      'Não foi possível conectar. O servidor pode estar '
                      'iniciando, aguarde alguns segundos.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _init,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              )
            else
              const LoadingIndicator(padding: EdgeInsets.symmetric(horizontal: 32)),
          ],
        ),
      ),
    );
  }
}
