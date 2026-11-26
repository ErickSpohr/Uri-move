import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/formats.dart';
import '../models/models.dart';
import '../state/auth_controller.dart';
import '../widgets/common.dart';
import '../widgets/user_safety.dart';

/// Perfil público de outro usuário: curso, câmpus, reputação e avaliações.
class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key, required this.user, this.rideId});

  /// Dados já conhecidos (exibidos enquanto o perfil completo carrega).
  final User user;

  /// Carona de contexto, usada ao denunciar.
  final int? rideId;

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  late User _user = widget.user;
  List<Map<String, dynamic>> _ratings = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = context.read<AuthController>().api;
    try {
      final results = await Future.wait([
        api.userProfile(widget.user.id),
        api.userRatings(widget.user.id),
      ]);
      if (!mounted) return;
      setState(() {
        _user = results[0] as User;
        _ratings = results[1] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Não foi possível carregar o perfil completo.';
        _loading = false;
      });
    }
  }

  /// Média de um critério (pontualidade, segurança...) entre as avaliações carregadas.
  double? _average(String key) {
    final values = [
      for (final r in _ratings)
        if (r[key] is num) (r[key] as num).toDouble(),
    ];
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final me = context.read<AuthController>().user;
    final user = _user;
    final isMe = me?.id == user.id;
    final subtitle = [
      user.course?.name,
      user.campus?.name,
    ].whereType<String>().join(' · ');

    final criteria = <(String, String)>[
      ('punctuality', 'Pontualidade'),
      ('communication', 'Comunicação'),
      ('safety', 'Segurança'),
      ('driving', 'Direção'),
      ('behavior', 'Comportamento'),
    ];
    final comments = _ratings
        .where((r) => (r['comment'] as String?)?.trim().isNotEmpty ?? false)
        .take(10)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        actions: [
          if (!isMe) UserSafetyMenu(user: user, rideId: widget.rideId),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: InitialsAvatar(
                name: user.name,
                photoUrl: user.photoUrl,
                radius: 48,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    user.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                ),
                if (user.isVerified) ...[
                  const SizedBox(width: 6),
                  Tooltip(
                    message: 'E-mail institucional verificado',
                    child: Icon(Icons.verified, color: scheme.primary, size: 22),
                  ),
                ],
              ],
            ),
            if (subtitle.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            if (user.createdAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'No URI Move desde ${formatDate(user.createdAt)}',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
                ),
              ),
            const SizedBox(height: 20),
            Row(
              children: [
                _Stat(
                  icon: Icons.star_rounded,
                  iconColor: Colors.amber,
                  value: user.ratingAvg?.toStringAsFixed(1) ?? '—',
                  label: user.ratingCount == 1
                      ? '1 avaliação'
                      : '${user.ratingCount} avaliações',
                ),
                const SizedBox(width: 10),
                _Stat(
                  icon: Icons.directions_car,
                  iconColor: scheme.primary,
                  value: '${user.rideCount}',
                  label: user.rideCount == 1 ? 'carona concluída' : 'caronas concluídas',
                ),
              ],
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(_error!, textAlign: TextAlign.center),
              )
            else ...[
              if (_ratings.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text('Avaliações por critério', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final (key, label) in criteria)
                  if (_average(key) case final average?)
                    _CriterionBar(label: label, value: average),
              ],
              const SizedBox(height: 24),
              Text('Comentários', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (comments.isEmpty)
                Text(
                  'Ainda não há comentários.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                )
              else
                for (final rating in comments) _CommentTile(rating: rating),
            ],
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: iconColor, size: 22),
                const SizedBox(width: 4),
                Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// Barra de 0 a 5 para a média de um critério.
class _CriterionBar extends StatelessWidget {
  const _CriterionBar({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: '$label: ${value.toStringAsFixed(1)} de 5',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(width: 118, child: Text(label, style: const TextStyle(fontSize: 13.5))),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (value / 5).clamp(0, 1),
                  minHeight: 8,
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(value.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.rating});

  final Map<String, dynamic> rating;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rater = rating['rater'] is Map
        ? User.fromJson(Map<String, dynamic>.from(rating['rater'] as Map))
        : null;
    final score = (rating['score'] as num?)?.toInt() ?? 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                InitialsAvatar(name: rater?.name ?? '?', photoUrl: rater?.photoUrl, radius: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    rater?.name ?? 'Usuário',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Semantics(
                  label: '$score de 5 estrelas',
                  excludeSemantics: true,
                  child: Row(
                    children: [
                      for (var i = 1; i <= 5; i++)
                        Icon(
                          i <= score ? Icons.star_rounded : Icons.star_outline_rounded,
                          size: 16,
                          color: Colors.amber,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(rating['comment'] as String),
            if (rating['created_at'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  formatDate(rating['created_at'] as String?),
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
