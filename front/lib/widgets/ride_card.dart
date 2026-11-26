import 'package:flutter/material.dart';

import '../core/formats.dart';
import '../core/theme.dart';
import '../models/models.dart';
import 'common.dart';

/// Card de carona usado na listagem (home, minhas caronas).
class RideCard extends StatelessWidget {
  const RideCard({
    super.key,
    required this.ride,
    this.onTap,
    this.compact = false,
  });

  final Ride ride;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ride.origin,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Icon(
                                Icons.arrow_downward,
                                size: 16,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  ride.destination,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Preço nulo = gratuita (formatPrice exibe "Grátis").
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (ride.costSharing && ride.price != null)
                        Text(
                          'a partir de',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      Text(
                        formatPrice(ride.myPrice ?? ride.price),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Wrap evita estouro horizontal em telas estreitas.
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _InfoChip(
                    icon: Icons.calendar_today_outlined,
                    label: formatDate(ride.departureDate),
                  ),
                  _InfoChip(
                    icon: Icons.schedule,
                    label: formatTime(ride.departureTime),
                  ),
                  _InfoChip(
                    icon: Icons.airline_seat_recline_normal,
                    label:
                        '${ride.availableSeats} vaga${ride.availableSeats == 1 ? '' : 's'}',
                  ),
                  if (ride.womenOnly)
                    const _InfoChip(icon: Icons.female, label: 'Só mulheres'),
                  if (ride.isRecurring)
                    const _InfoChip(icon: Icons.repeat, label: 'Semanal'),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  InitialsAvatar(
                    name: ride.driver.name,
                    photoUrl: ride.driver.photoUrl,
                    radius: 14,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ride.driver.name,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (ride.driver.ratingAvg != null) ...[
                    const Icon(
                      Icons.star_rounded,
                      size: 18,
                      color: Colors.amber,
                    ),
                    Text(
                      ride.driver.ratingAvg!.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (ride.isActive) ...[
                    const SizedBox(width: 8),
                    const _StatusBadge(
                      label: 'Em andamento',
                      color: AppTheme.accent,
                    ),
                  ] else if (ride.isCancelled) ...[
                    const SizedBox(width: 8),
                    const _StatusBadge(
                      label: 'Cancelada',
                      color: Colors.redAccent,
                    ),
                  ] else if (ride.isCompleted) ...[
                    const SizedBox(width: 8),
                    const _StatusBadge(label: 'Concluída', color: Colors.green),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
