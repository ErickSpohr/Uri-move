import 'dart:async';

import 'package:flutter/material.dart';

/// Aviso no topo da tela para notificações recebidas com o app aberto,
/// no estilo das notificações do sistema: desliza de cima, some sozinho
/// em 5 s e pode ser dispensado arrastando para cima.
class InAppNotification {
  InAppNotification._();

  static OverlayEntry? _current;
  static Timer? _timer;

  static IconData iconFor(String? type) => switch (type) {
    'chat_message' => Icons.chat_bubble_rounded,
    'ride_request_received' => Icons.person_add_alt_1_rounded,
    'ride_request_accepted' => Icons.check_circle_rounded,
    'ride_request_rejected' => Icons.cancel_rounded,
    'ride_cancelled' => Icons.event_busy_rounded,
    'driver_near' => Icons.directions_car_rounded,
    'driver_arrived' => Icons.place_rounded,
    'rating_received' => Icons.star_rounded,
    'ride_updated' => Icons.edit_calendar_rounded,
    _ => Icons.notifications_rounded,
  };

  static void show(
    OverlayState overlay, {
    required String title,
    String? body,
    String? type,
    VoidCallback? onTap,
  }) {
    dismiss();
    final key = GlobalKey<_BannerState>();
    _current = OverlayEntry(
      builder: (_) => _Banner(
        key: key,
        title: title,
        body: body,
        icon: iconFor(type),
        onTap: onTap,
        onDismissed: dismiss,
      ),
    );
    overlay.insert(_current!);
    _timer = Timer(const Duration(seconds: 5), () => key.currentState?.close());
  }

  static void dismiss() {
    _timer?.cancel();
    _timer = null;
    _current?.remove();
    _current = null;
  }
}

class _Banner extends StatefulWidget {
  const _Banner({
    super.key,
    required this.title,
    required this.body,
    required this.icon,
    required this.onDismissed,
    this.onTap,
  });

  final String title;
  final String? body;
  final IconData icon;
  final VoidCallback? onTap;
  final VoidCallback onDismissed;

  @override
  State<_Banner> createState() => _BannerState();
}

class _BannerState extends State<_Banner> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
    reverseDuration: const Duration(milliseconds: 200),
  )..forward();

  late final Animation<Offset> _slide = Tween(
    begin: const Offset(0, -1.2),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  bool _closing = false;

  Future<void> close() async {
    if (_closing || !mounted) return;
    _closing = true;
    await _controller.reverse();
    widget.onDismissed();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: SlideTransition(
          position: _slide,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: GestureDetector(
              onVerticalDragEnd: (details) {
                if ((details.primaryVelocity ?? 0) < 0) close();
              },
              child: Semantics(
                liveRegion: true,
                label: 'Notificação: ${widget.title}. ${widget.body ?? ''}',
                excludeSemantics: true,
                child: Material(
                  elevation: 8,
                  shadowColor: Colors.black45,
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(18),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      close();
                      widget.onTap?.call();
                    },
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(widget.icon, color: scheme.onPrimary, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        widget.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      'agora',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                                if (widget.body != null && widget.body!.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.body!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: scheme.onSurfaceVariant, height: 1.3),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Fechar',
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: close,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
