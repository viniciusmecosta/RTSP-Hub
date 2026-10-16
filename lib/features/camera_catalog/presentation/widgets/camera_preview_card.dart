import 'dart:math';

import 'package:flutter/material.dart';

import '../../domain/camera_device.dart';
import '../camera_thumbnail.dart';

class CameraPreviewCard extends StatelessWidget {
  const CameraPreviewCard({
    required this.camera,
    required this.onPreview,
    this.showHost = true,
    this.onEdit,
    this.onClone,
    this.onDelete,
    super.key,
  });

  final CameraDevice camera;
  final VoidCallback onPreview;
  final bool showHost;
  final VoidCallback? onEdit;
  final VoidCallback? onClone;
  final VoidCallback? onDelete;

  static double heightFor(
    double width,
    TextScaler textScaler, {
    bool showHost = true,
  }) =>
      width * 9 / 16 +
      max(
        48,
        textScaler.scale(22) + (showHost ? textScaler.scale(18) + 4 : 0),
      ) +
      16;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final hasMenu = onEdit != null || onClone != null || onDelete != null;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPreview,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CameraThumbnail(
                    cameraId: camera.id,
                    borderRadius: BorderRadius.zero,
                  ),
                  Positioned(
                    left: 10,
                    top: 10,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        child: Text(
                          'Imagem salva',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: IconButton.filled(
                      onPressed: onPreview,
                      tooltip: 'Ver vídeo de ${camera.name}',
                      icon: const Icon(Icons.play_arrow_rounded),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          camera.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium,
                        ),
                        if (showHost) ...[
                          const SizedBox(height: 4),
                          Text(
                            camera.host,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (hasMenu)
                    PopupMenuButton<String>(
                      tooltip: 'Opções de ${camera.name}',
                      onSelected: (value) => switch (value) {
                        'edit' => onEdit?.call(),
                        'clone' => onClone?.call(),
                        'delete' => onDelete?.call(),
                        _ => null,
                      },
                      itemBuilder: (_) => [
                        if (onEdit != null)
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Editar câmera'),
                          ),
                        if (onClone != null)
                          const PopupMenuItem(
                            value: 'clone',
                            child: Text('Clonar câmera'),
                          ),
                        if (onDelete != null)
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Remover câmera'),
                          ),
                      ],
                    )
                  else
                    const SizedBox(
                      width: 44,
                      height: 48,
                      child: Icon(Icons.chevron_right_rounded, size: 20),
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
