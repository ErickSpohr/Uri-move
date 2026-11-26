import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../models/models.dart';
import '../state/auth_controller.dart';

/// Motivos aceitos pela API (`Report::REASONS`) e seus rótulos.
const Map<String, String> reportReasons = {
  'misconduct': 'Conduta inadequada',
  'harassment': 'Assédio',
  'dangerous_driving': 'Direção perigosa',
  'fraud': 'Fraude ou golpe',
  'fake_profile': 'Perfil falso',
  'other': 'Outro motivo',
};

enum _SafetyAction { report, block }

/// Menu "⋮" com Denunciar e Bloquear para outro usuário.
/// [onBlocked] é chamado após bloqueio confirmado (ex.: fechar a tela de chat).
class UserSafetyMenu extends StatelessWidget {
  const UserSafetyMenu({
    super.key,
    required this.user,
    this.rideId,
    this.onBlocked,
  });

  final User user;
  final int? rideId;
  final VoidCallback? onBlocked;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_SafetyAction>(
      tooltip: 'Mais opções',
      icon: const Icon(Icons.more_vert),
      onSelected: (action) async {
        switch (action) {
          case _SafetyAction.report:
            await showReportDialog(context, user: user, rideId: rideId);
          case _SafetyAction.block:
            final blocked = await confirmAndBlockUser(context, user);
            if (blocked) {
              onBlocked?.call();
            }
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: _SafetyAction.report,
          child: ListTile(
            leading: Icon(Icons.flag_outlined),
            title: Text('Denunciar'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: _SafetyAction.block,
          child: ListTile(
            leading: Icon(Icons.block, color: Colors.redAccent),
            title: Text('Bloquear'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}

/// Abre o formulário de denúncia. Retorna `true` se a denúncia foi registrada.
Future<bool> showReportDialog(
  BuildContext context, {
  required User user,
  int? rideId,
}) async {
  final sent = await showDialog<bool>(
    context: context,
    builder: (_) => _ReportDialog(user: user, rideId: rideId),
  );
  if (sent == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Denúncia registrada. Nossa equipe irá analisar.'),
      ),
    );
  }
  return sent == true;
}

/// Confirma e bloqueia o usuário. Retorna `true` se o bloqueio foi feito.
Future<bool> confirmAndBlockUser(BuildContext context, User user) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Bloquear ${user.name}?'),
      content: const Text(
        'Vocês não poderão trocar mensagens privadas. '
        'Você pode desbloquear depois em Perfil → Usuários bloqueados.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Bloquear'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) {
    return false;
  }

  final messenger = ScaffoldMessenger.of(context);
  try {
    await context.read<AuthController>().api.blockUser(user.id);
    messenger.showSnackBar(SnackBar(content: Text('${user.name} foi bloqueado.')));
    return true;
  } on ApiException catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text(e.message), backgroundColor: Colors.red.shade700),
    );
    return false;
  }
}

class _ReportDialog extends StatefulWidget {
  const _ReportDialog({required this.user, this.rideId});

  final User user;
  final int? rideId;

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  final _detailsController = TextEditingController();
  String? _reason;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_reason == null) {
      setState(() => _error = 'Escolha um motivo.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await context.read<AuthController>().api.createReport(
        reportedId: widget.user.id,
        rideId: widget.rideId,
        reason: _reason!,
        details: _detailsController.text.trim(),
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Denunciar ${widget.user.name}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _reason,
              decoration: const InputDecoration(labelText: 'Motivo'),
              items: reportReasons.entries
                  .map(
                    (entry) => DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                  )
                  .toList(),
              onChanged: _sending
                  ? null
                  : (value) => setState(() => _reason = value),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _detailsController,
              enabled: !_sending,
              maxLines: 4,
              maxLength: 2000,
              decoration: const InputDecoration(
                labelText: 'Detalhes (opcional)',
                alignLabelWithHint: true,
              ),
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _sending ? null : _submit,
          child: _sending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Enviar denúncia'),
        ),
      ],
    );
  }
}
