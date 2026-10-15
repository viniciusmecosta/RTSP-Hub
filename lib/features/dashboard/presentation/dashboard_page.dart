import 'package:flutter/material.dart';

import '../../../app/state/app_store.dart';
import '../../../shared/design_system/page_frame.dart';
import '../../camera_catalog/presentation/camera_preview_dialog.dart';
import '../../camera_catalog/presentation/camera_thumbnail.dart';
import '../../settings/presentation/global_connection_page.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({
    required this.onAddCamera,
    required this.onOpenMonitor,
    this.onOpenProfile,
    this.onOpenLayouts,
    super.key,
  });

  final VoidCallback onAddCamera;
  final VoidCallback onOpenMonitor;
  final VoidCallback? onOpenLayouts;
  final ValueChanged<String>? onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final colors = Theme.of(context).colorScheme;
    final profile = store.lastSavedProfile;
    final selected = store.config.slotCameraIds.whereType<String>().length;
    return PageFrame(
      title: 'Visão geral',
      subtitle: 'RTSP Hub · Sua central de monitoramento',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.monitor, size: 28, color: colors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Monitor ao vivo',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    selected > 0
                        ? '$selected câmeras selecionadas. Abra sua grade para acompanhar as imagens.'
                        : 'Prepare suas câmeras e escolha como quer acompanhar as imagens.',
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        avatar: const Icon(Icons.videocam_outlined, size: 18),
                        label: Text('${store.cameras.length} cadastradas'),
                      ),
                      Chip(
                        avatar: const Icon(Icons.grid_view, size: 18),
                        label: Text(store.activeLayout.name),
                      ),
                      const Chip(
                        avatar: Icon(Icons.devices, size: 18),
                        label: Text('Dados neste dispositivo'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: store.cameras.isEmpty
                            ? onAddCamera
                            : onOpenMonitor,
                        icon: Icon(
                          store.cameras.isEmpty ? Icons.add : Icons.play_arrow,
                        ),
                        label: Text(
                          store.cameras.isEmpty
                              ? 'Adicionar câmera'
                              : 'Abrir monitor',
                        ),
                      ),
                      if (profile != null && onOpenProfile != null)
                        OutlinedButton.icon(
                          onPressed: () => onOpenProfile!(profile.id),
                          icon: const Icon(Icons.history),
                          label: Text(
                            'Acesso rápido · ${profile.name}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Comece pelo essencial',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1000
                  ? 3
                  : constraints.maxWidth >= 660
                  ? 2
                  : 1;
              final width =
                  (constraints.maxWidth - 12 * (columns - 1)) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: width,
                    child: _SetupCard(
                      number: '01',
                      title: 'Conexão global',
                      description:
                          'Defina usuário, senha, porta e canais uma vez.',
                      icon: Icons.settings_ethernet,
                      onTap: () => GlobalConnectionPage.open(context),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _SetupCard(
                      number: '02',
                      title: 'Suas câmeras',
                      description:
                          'Cadastre por IP ou encontre dispositivos na rede.',
                      icon: Icons.videocam_outlined,
                      onTap: onAddCamera,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _SetupCard(
                      number: '03',
                      title: 'Seu layout',
                      description:
                          'Escolha as posições e salve seus perfis de visualização.',
                      icon: Icons.grid_view,
                      onTap: onOpenLayouts ?? onOpenMonitor,
                    ),
                  ),
                ],
              );
            },
          ),
          if (store.cameras.isNotEmpty) ...[
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Acesso às câmeras',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton(
                  onPressed: onAddCamera,
                  child: const Text('Ver todas'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  for (final camera in store.cameras.take(4))
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: SizedBox(
                        width: 72,
                        height: 48,
                        child: CameraThumbnail(cameraId: camera.id),
                      ),
                      title: Text(
                        camera.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(camera.host),
                      trailing: const Icon(Icons.play_circle_outline),
                      onTap: () =>
                          CameraPreviewDialog.openSaved(context, store, camera),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SetupCard extends StatelessWidget {
  const _SetupCard({
    required this.number,
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });
  final String number;
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: colors.primary),
                  const Spacer(),
                  Text(
                    number,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                description,
                style: TextStyle(color: colors.onSurfaceVariant, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
