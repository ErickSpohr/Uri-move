import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../models/models.dart';
import '../state/auth_controller.dart';

/// Conversa privada entre o motorista e quem solicitou a carona.
class PrivateRideChatScreen extends StatefulWidget {
  const PrivateRideChatScreen({
    super.key,
    required this.ride,
    required this.otherUser,
  });

  final Ride ride;
  final User otherUser;

  @override
  State<PrivateRideChatScreen> createState() => _PrivateRideChatScreenState();
}

class _PrivateRideChatScreenState extends State<PrivateRideChatScreen> {
  final _text = TextEditingController();
  final _messages = <int, Map<String, dynamic>>{};
  Timer? _timer;
  late ApiClient _api;
  late int _userId;
  bool _loading = true;
  bool _sending = false;
  bool _fetching = false;
  String? _error;

  String get _path => '/rides/${widget.ride.id}/messages';

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthController>();
    _api = auth.api.client;
    _userId = auth.user!.id;
    _load();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _text.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_fetching) return;
    _fetching = true;
    try {
      final response = await _api
          .get(_path, query: {'user_id': '${widget.otherUser.id}'})
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      setState(() {
        for (final item in dataList(response)) {
          final message = Map<String, dynamic>.from(item as Map);
          _messages[message['id'] as int] = message;
        }
        _loading = false;
        _error = null;
      });
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Sem conexão. Tentando novamente…';
        });
      }
    } finally {
      _fetching = false;
    }
  }

  Future<void> _send() async {
    final body = _text.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final response = await _api.post(
        _path,
        body: {'body': body, 'receiver_id': widget.otherUser.id},
      );
      if (!mounted) return;
      final message = Map<String, dynamic>.from(
        response['chat_message'] as Map,
      );
      setState(() {
        _messages[message['id'] as int] = message;
        _text.clear();
        _error = null;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Não foi possível enviar a mensagem.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = _messages.values.toList()
      ..sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));
    return Scaffold(
      appBar: AppBar(title: Text('Conversa com ${widget.otherUser.name}')),
      body: Column(
        children: [
          if (_error != null)
            MaterialBanner(
              content: Text(_error!),
              actions: [
                TextButton(
                  onPressed: _load,
                  child: const Text('Tentar novamente'),
                ),
              ],
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : messages.isEmpty
                ? const Center(child: Text('Envie a primeira mensagem.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final sender = message['sender'] as Map?;
                      final mine = sender?['id'] == _userId;
                      return Align(
                        alignment: mine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Card(
                          color: mine
                              ? Theme.of(context).colorScheme.primaryContainer
                              : null,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            child: Text(message['body'] as String? ?? ''),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _text,
                      maxLines: 3,
                      minLines: 1,
                      maxLength: 2000,
                      decoration: const InputDecoration(
                        hintText: 'Escreva uma mensagem',
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Enviar mensagem',
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
