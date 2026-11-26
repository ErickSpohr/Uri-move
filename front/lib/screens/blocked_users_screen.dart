import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../models/models.dart';
import '../state/auth_controller.dart';
import '../widgets/common.dart';

/// Lista de usuários bloqueados, com opção de desbloquear.
class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  List<User> _users = [];
  bool _loading = true;
  String? _error;
  final Set<int> _unblocking = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final users = await context.read<AuthController>().api.blockedUsers();
      if (mounted) {
        setState(() {
          _users = users;
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _unblock(User user) async {
    setState(() => _unblocking.add(user.id));
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<AuthController>().api.unblockUser(user.id);
      if (!mounted) {
        return;
      }
      setState(() => _users.removeWhere((u) => u.id == user.id));
      messenger.showSnackBar(
        SnackBar(content: Text('${user.name} foi desbloqueado.')),
      );
    } on ApiException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red.shade700),
      );
    } finally {
      if (mounted) {
        setState(() => _unblocking.remove(user.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Usuários bloqueados')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!),
                  TextButton(
                    onPressed: _load,
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            )
          : _users.isEmpty
          ? const EmptyState(
              icon: Icons.block,
              message: 'Você não bloqueou ninguém.',
            )
          : ListView.separated(
              itemCount: _users.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final user = _users[index];
                return ListTile(
                  leading: InitialsAvatar(
                    name: user.name,
                    photoUrl: user.photoUrl,
                  ),
                  title: Text(user.name),
                  subtitle: user.course != null ? Text(user.course!.name) : null,
                  trailing: _unblocking.contains(user.id)
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : TextButton(
                          onPressed: () => _unblock(user),
                          child: const Text('Desbloquear'),
                        ),
                );
              },
            ),
    );
  }
}
