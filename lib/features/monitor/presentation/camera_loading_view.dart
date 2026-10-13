import 'package:flutter/material.dart';

import '../application/rtsp_session.dart';

class CameraLoadingView extends StatelessWidget {
  const CameraLoadingView({
    required this.status,
    this.error,
    this.retryDelay,
    this.onRetry,
    super.key,
  });

  final CameraPlaybackStatus status;
  final String? error;
  final Duration? retryDelay;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final loading =
        status == CameraPlaybackStatus.idle ||
        status == CameraPlaybackStatus.connecting ||
        status == CameraPlaybackStatus.reconnecting;
    final title = switch (status) {
      CameraPlaybackStatus.idle => 'Preparando câmera',
      CameraPlaybackStatus.connecting => 'Conectando à câmera',
      CameraPlaybackStatus.playing => 'Aguardando vídeo',
      CameraPlaybackStatus.reconnecting => 'Reconectando à câmera',
      CameraPlaybackStatus.error => 'Câmera indisponível',
      CameraPlaybackStatus.paused => 'Câmera pausada',
    };
    final explanation = switch (status) {
      CameraPlaybackStatus.reconnecting when error != null => error!,
      CameraPlaybackStatus.reconnecting => 'Nova tentativa automática em breve',
      CameraPlaybackStatus.error when error != null => error!,
      CameraPlaybackStatus.error => 'Confira a rede e os dados da câmera',
      CameraPlaybackStatus.connecting => 'Aguardando o primeiro quadro',
      _ => '',
    };
    final secondary =
        retryDelay == null || status != CameraPlaybackStatus.reconnecting
        ? explanation
        : '$explanation · Nova tentativa em ${retryDelay!.inSeconds} s';
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxHeight < 145 || constraints.maxWidth < 220;
        final tiny = constraints.maxHeight < 90;
        return ColoredBox(
          color: const Color(0xFF0D1725),
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(tiny ? 4 : 12),
              child: Semantics(
                liveRegion: true,
                label: secondary.isEmpty ? title : '$title. $secondary',
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!tiny &&
                        loading &&
                        !MediaQuery.disableAnimationsOf(context))
                      const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF8FB7FF),
                        ),
                      )
                    else if (!tiny && status != CameraPlaybackStatus.error)
                      const Icon(
                        Icons.videocam_outlined,
                        size: 24,
                        color: Color(0xFF8FB7FF),
                      ),
                    if (!tiny || status != CameraPlaybackStatus.error) ...[
                      if (!tiny) const SizedBox(height: 8),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (!compact && secondary.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        secondary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFB9C7D9),
                          fontSize: 11,
                        ),
                      ),
                    ],
                    if (status == CameraPlaybackStatus.error &&
                        onRetry != null) ...[
                      if (!tiny) const SizedBox(height: 6),
                      if (tiny)
                        IconButton(
                          onPressed: onRetry,
                          tooltip: 'Tentar novamente',
                          icon: const Icon(Icons.refresh),
                        )
                      else if (compact)
                        TextButton(
                          onPressed: onRetry,
                          child: const Text('Tentar novamente'),
                        )
                      else
                        TextButton.icon(
                          onPressed: onRetry,
                          icon: const Icon(Icons.refresh, size: 17),
                          label: const Text('Tentar novamente'),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
