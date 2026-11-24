import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../state/auth_controller.dart';
import '../widgets/common.dart';

class PasswordRecoveryScreen extends StatefulWidget {
  const PasswordRecoveryScreen({super.key, this.email = ''});

  final String email;

  @override
  State<PasswordRecoveryScreen> createState() => _PasswordRecoveryScreenState();
}

class _PasswordRecoveryScreenState extends State<PasswordRecoveryScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _email = TextEditingController(
    text: widget.email,
  );
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _codeRequested = false;
  bool _busy = false;
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _sendCode({bool resend = false}) async {
    if (_busy || (!resend && !_formKey.currentState!.validate())) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthController>().api.forgotPassword(
        _email.text.trim().toLowerCase(),
      );
      if (!mounted) return;
      setState(() => _codeRequested = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Se o e-mail estiver cadastrado, enviaremos o código. Confira a caixa de entrada e o spam.',
          ),
        ),
      );
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Não foi possível conectar ao servidor. Tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthController>().api.resetPassword(
        _email.text.trim().toLowerCase(),
        _code.text.trim(),
        _password.text,
        _confirmation.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Senha atualizada. Entre com sua nova senha.'),
        ),
      );
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Não foi possível conectar ao servidor. Tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Esqueci minha senha')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _codeRequested
                        ? 'Copie o código completo recebido no e-mail e escolha uma nova senha. O código expira em 60 minutos.'
                        : 'Informe seu e-mail institucional para recuperar o acesso.',
                  ),
                  const SizedBox(height: 20),
                  if (_error != null) ...[
                    ErrorBanner(
                      message: _error!,
                      onDismiss: () => setState(() => _error = null),
                    ),
                    const SizedBox(height: 14),
                  ],
                  TextFormField(
                    controller: _email,
                    readOnly: _codeRequested,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'E-mail institucional',
                      prefixIcon: Icon(Icons.mail_outline),
                    ),
                    validator: (v) => (v == null || !v.trim().contains('@'))
                        ? 'Informe seu e-mail'
                        : null,
                  ),
                  if (_codeRequested) ...[
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _code,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                        labelText: 'Código de recuperação',
                      ),
                      validator: (v) => v?.trim().length != 64
                          ? 'Cole o código completo do e-mail'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscurePassword,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: 'Nova senha (mín. 8)',
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword
                              ? 'Mostrar senha'
                              : 'Ocultar senha',
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                      validator: (v) => (v == null || v.length < 8)
                          ? 'Use pelo menos 8 caracteres'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _confirmation,
                      obscureText: _obscureConfirmation,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: 'Confirmar nova senha',
                        suffixIcon: IconButton(
                          tooltip: _obscureConfirmation
                              ? 'Mostrar confirmação de senha'
                              : 'Ocultar confirmação de senha',
                          icon: Icon(
                            _obscureConfirmation
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () => setState(
                            () => _obscureConfirmation = !_obscureConfirmation,
                          ),
                        ),
                      ),
                      validator: (v) =>
                          v != _password.text ? 'As senhas não conferem' : null,
                    ),
                  ],
                  const SizedBox(height: 22),
                  PrimaryButton(
                    label: _codeRequested
                        ? 'Salvar nova senha'
                        : 'Enviar código',
                    loading: _busy,
                    onPressed: _codeRequested ? _reset : () => _sendCode(),
                  ),
                  if (_codeRequested) ...[
                    TextButton(
                      onPressed: _busy ? null : () => _sendCode(resend: true),
                      child: const Text('Reenviar código'),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                              _codeRequested = false;
                              _error = null;
                              _code.clear();
                            }),
                      child: const Text('Usar outro e-mail'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
