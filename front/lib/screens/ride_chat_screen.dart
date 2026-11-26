import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../models/models.dart';
import '../state/auth_controller.dart';

class RideChatScreen extends StatefulWidget {
  const RideChatScreen({super.key, required this.ride});
  final Ride ride;

  @override
  State<RideChatScreen> createState() => _RideChatScreenState();
}

class _RideChatScreenState extends State<RideChatScreen>
    with WidgetsBindingObserver {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <int, Map<String, dynamic>>{};
  Timer? _timer;
  late ApiClient _api;
  late int _userId;
  bool _loading = true;
  bool _fetching = false;
  bool _sending = false;
  bool _hasOlder = true;
  bool _denied = false;
  bool _paused = false;
  String? _error;

  String get _path => '/rides/${widget.ride.id}/chat';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final auth = context.read<AuthController>();
    _api = auth.api.client;
    _userId = auth.user!.id;
    _load();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!_paused && !_denied) _load();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _paused = state != AppLifecycleState.resumed;
    if (!_paused && !_denied) _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool older = false}) async {
    if (_fetching || _denied) return;
    _fetching = true;
    final ids = _messages.keys.toList()..sort();
    final query = <String, String>{
      if (ids.isNotEmpty && older) 'before_id': '${ids.first}',
      if (ids.isNotEmpty && !older) 'after_id': '${ids.last}',
    };
    try {
      final json = await _api
          .get(_path, query: query)
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      final entries = dataList(json);
      final nearBottom = !_scroll.hasClients || _scroll.offset < 100;
      setState(() {
        for (final entry in entries) {
          final message = Map<String, dynamic>.from(entry as Map);
          _messages[message['id'] as int] = message;
        }
        if (older || ids.isEmpty) _hasOlder = entries.length == 50;
        _loading = false;
        _error = null;
      });
      if (!older && nearBottom && entries.isNotEmpty) _toBottom();
    } on ApiException catch (e) {
      _failed(e.message, denied: e.statusCode == 401 || e.statusCode == 403);
    } catch (_) {
      _failed('Sem conexão. Tentando reconectar…');
    } finally {
      _fetching = false;
    }
  }

  void _failed(String message, {bool denied = false}) {
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = message;
      _denied = denied;
      if (denied) _messages.clear();
    });
    if (denied) _timer?.cancel();
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) {
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final body = _text.text.trim();
    if (_sending || body.isEmpty || _denied) return;
    setState(() => _sending = true);
    try {
      await _api
          .post(_path, body: {'body': body})
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      _text.clear();
      await _load();
      _toBottom();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401 || e.statusCode == 403) {
        _failed(e.message, denied: true);
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível confirmar o envio. Confira o histórico antes de tentar novamente.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = _messages.values.toList()
      ..sort((a, b) => (b['id'] as int).compareTo(a['id'] as int));
    final readOnly = widget.ride.isCompleted || widget.ride.isCancelled;
    return Scaffold(
      appBar: AppBar(title: const Text('Chat da carona')),
      body: SafeArea(
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.groups_outlined),
              title: Text('${widget.ride.origin} → ${widget.ride.destination}'),
              subtitle: const Text(
                'Grupo do motorista e passageiros confirmados',
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : entries.isEmpty
                  ? const Center(
                      child: Text('Combine o ponto de encontro por aqui.'),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      reverse: true,
                      padding: const EdgeInsets.all(16),
                      itemCount: entries.length + (_hasOlder ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == entries.length) {
                          return TextButton(
                            onPressed: () => _load(older: true),
                            child: const Text('Carregar mensagens anteriores'),
                          );
                        }
                        final item = entries[index];
                        final sender = item['sender'] as Map;
                        final mine = sender['id'] == _userId;
                        final sentAt = DateTime.tryParse(
                          item['created_at'] as String? ?? '',
                        )?.toLocal();
                        final time = sentAt == null
                            ? ''
                            : '${sentAt.day.toString().padLeft(2, '0')}/${sentAt.month.toString().padLeft(2, '0')} '
                                  '${sentAt.hour.toString().padLeft(2, '0')}:${sentAt.minute.toString().padLeft(2, '0')}';
                        return Align(
                          alignment: mine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 420),
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: mine
                                  ? Theme.of(context)
                                        .colorScheme
                                        .primaryContainer
                                  : Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${sender['name']}${sender['id'] == widget.ride.driver.id ? ' · Motorista' : ''}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                SelectableText(item['body'] as String),
                                const SizedBox(height: 4),
                                Text(
                                  time,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            if (readOnly)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Carona encerrada. Histórico disponível para leitura.',
                ),
              )
            else if (!_denied)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _text,
                        enabled: !_sending,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: 2000,
                        decoration: const InputDecoration(
                          hintText: 'Escreva uma mensagem…',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      tooltip: 'Enviar mensagem',
                      onPressed: _sending ? null : _send,
                      icon: _sending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
