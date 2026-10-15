import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../camera_catalog/domain/camera_device.dart';
import '../../application/rtsp_session.dart';
import '../camera_loading_view.dart';

class MonitorCameraTile extends StatelessWidget {
  const MonitorCameraTile({
    required this.camera,
    required this.session,
    required this.onTap,
    required this.onFocus,
    this.onClone,
    this.onSwitchChannel,
    required this.onRetry,
    super.key,
  });

  final CameraDevice? camera;
  final RtspSession? session;
  final VoidCallback onTap;
  final VoidCallback? onFocus;
  final VoidCallback? onClone;
  final ValueChanged<String>? onSwitchChannel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final currentSession = session;
    if (currentSession == null) return _content(context);
    return ListenableBuilder(
      listenable: currentSession,
      builder: (context, _) => _content(context),
    );
  }

  Widget _content(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onFocus,
      onSecondaryTap: onFocus,
      child: ColoredBox(
        color: const Color(0xFF111821),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (session?.videoController != null)
              Video(
                controller: session!.videoController!,
                fit: BoxFit.contain,
                fill: Colors.black,
                controls: NoVideoControls,
              )
            else if (camera == null)
              const Center(
                child: Icon(
                  Icons.videocam_off_outlined,
                  size: 32,
                  color: Color(0xFF526174),
                ),
              )
            else
              const SizedBox.shrink(),
            if (camera == null)
              const Center(
                child: Text(
                  'Posição vazia',
                  style: TextStyle(color: Color(0xFF8A98AA)),
                ),
              ),
            if (camera != null && session?.firstFrameRendered.value != true)
              Positioned.fill(
                child: CameraLoadingView(
                  status: session?.status.value ?? CameraPlaybackStatus.idle,
                  error: session?.error.value,
                  retryDelay: session?.nextRetryDelay,
                  onRetry: onRetry,
                ),
              ),
            if (camera != null)
              Positioned(
                left: 8,
                bottom: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.58),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 4,
                    ),
                    child: Text(
                      camera!.savedPaths.length > 1
                          ? '${camera!.name} (${camera!.mainPath})'
                          : camera!.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            if (camera != null)
              Positioned(
                top: 6,
                right: 6,
                child: Material(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(16),
                  child: PopupMenuButton<String>(
                    tooltip: 'Opções da câmera',
                    icon: const Icon(
                      Icons.more_vert,
                      color: Colors.white,
                      size: 18,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 140),
                    onSelected: (value) {
                      if (value == 'focus') {
                        onFocus?.call();
                      } else if (value == 'clone') {
                        onClone?.call();
                      } else if (value.startsWith('channel:')) {
                        onSwitchChannel?.call(
                          value.substring('channel:'.length),
                        );
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'focus',
                        child: Row(
                          children: const [
                            Icon(Icons.fullscreen, size: 18),
                            SizedBox(width: 8),
                            Text('Focar câmera'),
                          ],
                        ),
                      ),
                      if (onClone != null)
                        const PopupMenuItem(
                          value: 'clone',
                          child: Row(
                            children: [
                              Icon(Icons.copy_outlined, size: 18),
                              SizedBox(width: 8),
                              Text('Clonar câmera'),
                            ],
                          ),
                        ),
                      if (camera != null && camera!.savedPaths.length > 1) ...[
                        const PopupMenuDivider(),
                        ...camera!.savedPaths.map(
                          (path) => PopupMenuItem(
                            value: 'channel:$path',
                            child: Row(
                              children: [
                                Icon(
                                  path ==
                                          (camera!.selectedPath.isEmpty
                                              ? camera!.mainPath
                                              : camera!.selectedPath)
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  size: 16,
                                  color:
                                      path ==
                                          (camera!.selectedPath.isEmpty
                                              ? camera!.mainPath
                                              : camera!.selectedPath)
                                      ? const Color(0xFF10B981)
                                      : Colors.white70,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Canal: $path',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight:
                                          path ==
                                              (camera!.selectedPath.isEmpty
                                                  ? camera!.mainPath
                                                  : camera!.selectedPath)
                                              ? FontWeight.w700
                                              : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class MonitorEmptyView extends StatelessWidget {
  const MonitorEmptyView({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white70, fontSize: 16),
      ),
    ),
  );
}
