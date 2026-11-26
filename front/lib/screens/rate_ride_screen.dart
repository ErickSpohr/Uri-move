import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../models/models.dart';
import '../state/auth_controller.dart';
import '../widgets/common.dart';
import '../widgets/user_safety.dart';

/// Avaliação dos participantes de uma carona concluída.
class RateRideScreen extends StatefulWidget {
  const RateRideScreen({super.key, required this.ride});

  final Ride ride;

  @override
  State<RateRideScreen> createState() => _RateRideScreenState();
}

class _RateRideScreenState extends State<RateRideScreen> {
  List<RideParticipant> _participants = [];
  bool _canRate = false;
  bool _loading = true;
  String? _error;

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
      final result = await context
          .read<AuthController>()
          .api
          .rideParticipants(widget.ride.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _participants = result.participants;
        _canRate = result.canRate;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    }
  }

  void _markRated(int userId) {
    setState(() {
      _participants = [
        for (final participant in _participants)
          participant.user.id == userId
              ? RideParticipant(
                  user: participant.user,
                  role: participant.role,
                  alreadyRated: true,
                )
              : participant,
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Avaliar carona')),
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
          : !_canRate
          ? const EmptyState(
              icon: Icons.star_outline,
              message: 'A avaliação fica disponível após a conclusão da carona.',
            )
          : _participants.isEmpty
          ? const EmptyState(
              icon: Icons.people_outline,
              message: 'Nenhum outro participante nesta carona.',
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  '${widget.ride.origin} → ${widget.ride.destination}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Sua avaliação ajuda a manter a comunidade segura.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                for (final participant in _participants)
                  _ParticipantRatingCard(
                    key: ValueKey(participant.user.id),
                    rideId: widget.ride.id,
                    participant: participant,
                    onRated: () => _markRated(participant.user.id),
                  ),
              ],
            ),
    );
  }
}

class _ParticipantRatingCard extends StatefulWidget {
  const _ParticipantRatingCard({
    super.key,
    required this.rideId,
    required this.participant,
    required this.onRated,
  });

  final int rideId;
  final RideParticipant participant;
  final VoidCallback onRated;

  @override
  State<_ParticipantRatingCard> createState() => _ParticipantRatingCardState();
}

class _ParticipantRatingCardState extends State<_ParticipantRatingCard> {
  final _commentController = TextEditingController();
  int _score = 0;
  bool _sending = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<AuthController>().api.rateUser(
        rideId: widget.rideId,
        ratedId: widget.participant.user.id,
        score: _score,
        comment: _commentController.text.trim(),
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text('Avaliação de ${widget.participant.user.name} enviada.'),
        ),
      );
      widget.onRated();
    } on ApiException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.participant.user;
    final colors = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 4, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                InitialsAvatar(name: user.name, photoUrl: user.photoUrl),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        widget.participant.isDriver ? 'Motorista' : 'Passageiro',
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                UserSafetyMenu(user: user, rideId: widget.rideId),
              ],
            ),
            const SizedBox(height: 8),
            if (widget.participant.alreadyRated)
              Row(
                children: [
                  Icon(Icons.check_circle, color: colors.primary, size: 20),
                  const SizedBox(width: 6),
                  const Text('Avaliação enviada'),
                ],
              )
            else ...[
              Row(
                children: [
                  for (var star = 1; star <= 5; star++)
                    IconButton(
                      tooltip: '$star de 5',
                      onPressed: _sending
                          ? null
                          : () => setState(() => _score = star),
                      icon: Icon(
                        star <= _score ? Icons.star : Icons.star_border,
                        color: Colors.amber.shade700,
                        size: 32,
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: TextField(
                  controller: _commentController,
                  enabled: !_sending,
                  maxLength: 1000,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Comentário (opcional)',
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: FilledButton(
                    onPressed: _score == 0 || _sending ? null : _submit,
                    child: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Enviar avaliação'),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
