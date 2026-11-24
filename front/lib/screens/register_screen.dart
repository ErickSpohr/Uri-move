import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../models/models.dart';
import '../state/auth_controller.dart';
import '../widgets/common.dart';
import 'verify_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _raController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _gender;
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;

  List<Campus> _campuses = [];
  List<Course> _courses = [];
  int? _campusId;
  int? _courseId;
  bool _loadingRefs = true;

  @override
  void initState() {
    super.initState();
    _loadRefs();
  }

  Future<void> _loadRefs() async {
    try {
      final api = context.read<AuthController>().api;
      final campuses = await api.campuses();
      final courses = await api.courses();
      if (!mounted) {
        return;
      }
      setState(() {
        _campuses = campuses;
        _courses = courses;
        _loadingRefs = false;
      });
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingRefs = false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Não foi possível carregar os dados: ${e.message}'),
          ),
        );
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingRefs = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _raController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit(AuthController auth) async {
    FocusScope.of(context).unfocus();
    if (_loadingRefs) {
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final ok = await auth.register(
      name: _nameController.text.trim(),
      email: _emailController.text.trim().toLowerCase(),
      password: _passwordController.text,
      ra: _raController.text.trim().isEmpty ? null : _raController.text.trim(),
      phone: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      gender: _gender,
      courseId: _courseId,
      campusId: _campusId,
    );
    if (!mounted) {
      return;
    }
    if (ok) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              VerifyScreen(email: _emailController.text.trim().toLowerCase()),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Criar conta')),
      body: SafeArea(
        child: _loadingRefs
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (auth.error != null) ...[
                        ErrorBanner(
                          message: auth.error!,
                          onDismiss: () => auth.clearError(),
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Nome completo',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Informe seu nome'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'E-mail institucional da URI',
                          prefixIcon: Icon(Icons.mail_outline),
                        ),
                        validator: (v) {
                          final value = v?.trim().toLowerCase() ?? '';
                          if (value.isEmpty) {
                            return 'Informe seu e-mail institucional';
                          }
                          if (!value.endsWith('@uri.edu.br') &&
                              !value.endsWith('@uri.br') &&
                              !value.endsWith('@aluno.santoangelo.uri.br')) {
                            return 'Use seu e-mail institucional da URI';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _raController,
                              decoration: const InputDecoration(
                                labelText: 'RA (opcional)',
                                prefixIcon: Icon(Icons.badge_outlined),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'Telefone (opcional)',
                                prefixIcon: Icon(Icons.phone_outlined),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: _gender,
                        decoration: const InputDecoration(
                          labelText: 'Gênero (opcional)',
                          prefixIcon: Icon(Icons.person_2_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'woman',
                            child: Text('Mulher'),
                          ),
                          DropdownMenuItem(value: 'man', child: Text('Homem')),
                          DropdownMenuItem(
                            value: 'non_binary',
                            child: Text('Não binário'),
                          ),
                          DropdownMenuItem(
                            value: 'other',
                            child: Text('Outro'),
                          ),
                          DropdownMenuItem(
                            value: 'prefer_not_to_say',
                            child: Text('Prefiro não informar'),
                          ),
                        ],
                        onChanged: (value) => setState(() => _gender = value),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<int>(
                        initialValue: _campusId,
                        decoration: const InputDecoration(labelText: 'Campus'),
                        items: _campuses
                            .map(
                              (c) => DropdownMenuItem(
                                value: c.id,
                                child: Text(c.name),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() {
                          _campusId = v;
                          _courseId = null;
                        }),
                      ),
                      if (_campusId != null) ...[
                        const SizedBox(height: 14),
                        DropdownButtonFormField<int>(
                          initialValue: _courseId,
                          decoration: const InputDecoration(labelText: 'Curso'),
                          items: _courses
                              .where((c) => c.campusId == _campusId)
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c.id,
                                  child: Text(c.name),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _courseId = v),
                        ),
                      ],
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: InputDecoration(
                          labelText: 'Senha (mín. 8)',
                          prefixIcon: const Icon(Icons.lock_outline),
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
                            ? 'A senha deve ter no mínimo 8 caracteres'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _confirmController,
                        obscureText: _obscureConfirmation,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: InputDecoration(
                          labelText: 'Confirmar senha',
                          prefixIcon: const Icon(Icons.lock_outline),
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
                              () =>
                                  _obscureConfirmation = !_obscureConfirmation,
                            ),
                          ),
                        ),
                        validator: (v) => (v != _passwordController.text)
                            ? 'As senhas não conferem'
                            : null,
                      ),
                      const SizedBox(height: 22),
                      PrimaryButton(
                        label: 'Criar conta',
                        loading: auth.busy,
                        onPressed: () => _submit(auth),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
