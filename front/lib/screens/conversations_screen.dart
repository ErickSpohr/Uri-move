import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../models/models.dart';
import '../state/auth_controller.dart';
import 'private_ride_chat_screen.dart';
import 'ride_chat_screen.dart';

/// Reúne as conversas das solicitações e das caronas do usuário.
class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key, required this.active});

  final bool active;

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  List<_Conversation> _conversations = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.active) _load();
  }

  @override
  void didUpdateWidget(covariant ConversationsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _load();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<AuthController>().api;
      final requests = await api.myRequests();
      final driven = await api.myRides();
      final joined = await api.myJoinedRides();
      final conversations = <_Conversation>[];
      final requestedRides = <int>{};

      for (final request in requests) {
        final ride = request.ride;
        if (ride == null ||
            ride.isCancelled ||
            ride.isCompleted ||
            !requestedRides.add(request.rideId)) {
          continue;
        }
        if (request.status == 'pending') {
          conversations.add(
            _Conversation(
              ride: ride,
              peer: ride.driver,
              title: ride.driver.name,
              detail:
                  'Aguardando resposta · ${ride.origin} → ${ride.destination}',
            ),
          );
        }
      }

      for (final ride in driven.where(
        (ride) => !ride.isCancelled && !ride.isCompleted,
      )) {
        final rideRequests = await api.rideRequests(ride.id);
        for (final request in rideRequests.where(
          (request) => request.isPending,
        )) {
          if (request.passenger != null) {
            conversations.add(
              _Conversation(
                ride: ride,
                peer: request.passenger,
                title: request.passenger!.name,
                detail:
                    'Solicitação pendente · ${ride.origin} → ${ride.destination}',
              ),
            );
          }
        }
      }

      for (final ride in [...driven, ...joined]) {
        if (ride.canChat && !ride.isCancelled) {
          conversations.add(
            _Conversation(
              ride: ride,
              title: 'Chat da carona',
              detail: '${ride.origin} → ${ride.destination}',
            ),
          );
        }
      }

      if (!mounted) return;
      setState(() {
        _conversations = conversations;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Não foi possível carregar as conversas.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _open(_Conversation conversation) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => conversation.peer == null
            ? RideChatScreen(ride: conversation.ride)
            : PrivateRideChatScreen(
                ride: conversation.ride,
                otherUser: conversation.peer!,
              ),
      ),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Conversas')),
      body: _loading && _conversations.isEmpty
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
          : RefreshIndicator(
              onRefresh: _load,
              child: _conversations.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 120),
                        Icon(Icons.chat_bubble_outline, size: 56),
                        SizedBox(height: 16),
                        Center(child: Text('Nenhuma conversa por enquanto.')),
                        Center(
                          child: Text(
                            'Solicite uma carona para falar com o motorista.',
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      itemCount: _conversations.length,
                      itemBuilder: (context, index) {
                        final conversation = _conversations[index];
                        return ListTile(
                          leading: CircleAvatar(
                            child: Icon(
                              conversation.peer == null
                                  ? Icons.groups_outlined
                                  : Icons.person_outline,
                            ),
                          ),
                          title: Text(conversation.title),
                          subtitle: Text(conversation.detail),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _open(conversation),
                        );
                      },
                    ),
            ),
    );
  }
}

class _Conversation {
  const _Conversation({
    required this.ride,
    required this.title,
    required this.detail,
    this.peer,
  });

  final Ride ride;
  final User? peer;
  final String title;
  final String detail;
}
