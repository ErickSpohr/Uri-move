import 'package:flutter/material.dart';

import '../core/api.dart';

/// Indicador de carregamento que, quando alguma requisição passa de
/// [ApiClient.slowThreshold], explica que o servidor está iniciando.
class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({super.key, this.padding = const EdgeInsets.all(32)});

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.8),
          ),
          ValueListenableBuilder<int>(
            valueListenable: ApiClient.slowRequests,
            builder: (context, slow, _) => AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: slow == 0
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          ApiClient.serverStartingMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
