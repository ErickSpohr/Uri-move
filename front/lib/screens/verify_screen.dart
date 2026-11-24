import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../state/auth_controller.dart';
import '../widgets/common.dart';
import 'main_shell.dart';

class VerifyScreen extends StatefulWidget {
  const VerifyScreen({super.key, required this.email});

  final String email;

  @override
  State<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends State<VerifyScreen> {
  final _codeController = TextEditingController();
  bool _sent = true;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit(AuthController auth) async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      return;
    }
    final ok = await auth.verify(widget.email, code);
    if (!mounted) {
      return;
    }
    if (ok) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const MainShell()));
    }
  }

  Future<void> _resend(AuthController auth) async {
    setState(() => _sent = false);
    await auth.resendCode(widget.email);
    if (!mounted) {
      return;
    }
    setState(() => _sent = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Um novo código foi enviado.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Verificar e-mail')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              const Center(
                child: Icon(
                  Icons.mark_email_read_outlined,
                  size: 64,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Código de verificação',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enviamos um código de 6 dígitos para\n${widget.email}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              if (auth.error != null) ...[
                ErrorBanner(
                  message: auth.error!,
                  onDismiss: () => auth.clearError(),
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                style: const TextStyle(
                  fontSize: 22,
                  letterSpacing: 8,
                  fontWeight: FontWeight.w700,
                ),
                decoration: const InputDecoration(
                  labelText: 'Código',
                  counterText: '',
                  hintText: '••••••',
                ),
                onFieldSubmitted: (_) => _submit(auth),
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: 'Verificar e continuar',
                loading: auth.busy,
                onPressed: () => _submit(auth),
              ),
              const SizedBox(height: 14),
              TextButton(
                onPressed: auth.busy || !_sent ? null : () => _resend(auth),
                child: const Text('Reenviar código'),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'Confira a caixa de entrada e a pasta de spam do seu e-mail '
                  'institucional. O código expira em 10 minutos. '
                  'Se não encontrar a mensagem, use Reenviar código.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
