import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Apresentação exibida no primeiro acesso do aparelho (e revista pela tela
/// "Como funciona"). [onDone] decide para onde ir ao terminar ou pular.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});

  static const _seenKey = 'onboarding_seen_v1';

  final VoidCallback onDone;

  static Future<bool> wasSeen() async =>
      (await SharedPreferences.getInstance()).getBool(_seenKey) ?? false;

  static Future<void> markSeen() async =>
      (await SharedPreferences.getInstance()).setBool(_seenKey, true);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _pages = <(IconData, String, String)>[
    (
      Icons.school_rounded,
      'Caronas entre quem é da URI',
      'Só entra quem tem e-mail institucional da URI.',
    ),
    (
      Icons.directions_car_rounded,
      'Encontre ou ofereça',
      'Procure caronas pelo destino e horário, ou ofereça a sua e publique '
          'a semana inteira de uma vez.',
    ),
    (
      Icons.local_gas_station_rounded,
      'Valor justo',
      'O preço divide o combustível e soma o desvio até você. '
          'O pagamento é por Pix.',
    ),
    (
      Icons.shield_rounded,
      'Viaje com segurança',
      'Veja o perfil e as avaliações, converse pelo chat e acompanhe o carro no mapa.',
    ),
  ];

  final _controller = PageController();
  int _page = 0;

  bool get _isLast => _page == _pages.length - 1;

  Future<void> _finish() async {
    await OnboardingScreen.markSeen();
    widget.onDone();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: TextButton(
                  onPressed: _isLast ? null : _finish,
                  child: Text(_isLast ? '' : 'Pular'),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (page) => setState(() => _page = page),
                itemBuilder: (context, index) {
                  final (icon, title, text) = _pages[index];
                  return Semantics(
                    label: 'Página ${index + 1} de ${_pages.length}',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(icon, size: 68, color: scheme.onPrimary),
                          ),
                          const SizedBox(height: 36),
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            text,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              height: 1.45,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _pages.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _page ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _page ? scheme.primary : scheme.outlineVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: _isLast
                      ? _finish
                      : () => _controller.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                        ),
                  child: Text(_isLast ? 'Começar' : 'Próximo'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
