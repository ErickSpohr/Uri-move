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
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.arrow_downward,
                                size: 16,
                                color: AppTheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                ride.destination,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (ride.price != null)
                    Text(
                      formatPrice(ride.price),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _InfoChip(
                    icon: Icons.calendar_today_outlined,
                    label: formatDate(ride.departureDate),
                  ),
                  const SizedBox(width: 8),
                  _InfoChip(
                    icon: Icons.schedule,
                    label: formatTime(ride.departureTime),
                  ),
                  const SizedBox(width: 8),
                  _InfoChip(
                    icon: Icons.airline_seat_recline_normal,
                    label:
                        '${ride.availableSeats} vaga${ride.availableSeats == 1 ? '' : 's'}',
                  ),
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
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
