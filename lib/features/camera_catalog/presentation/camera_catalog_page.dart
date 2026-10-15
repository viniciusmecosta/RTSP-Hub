import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/state/app_store.dart';
import '../../../shared/design_system/page_frame.dart';
import '../../settings/presentation/global_connection_page.dart';
import '../domain/camera_device.dart';
import 'camera_editor_dialog.dart';
import 'camera_preview_dialog.dart';
import 'camera_thumbnail.dart';
import 'clone_camera_dialog.dart';
import 'network_camera_discovery.dart';

class CameraCatalogPage extends StatefulWidget {
  const CameraCatalogPage({super.key});

  @override
  State<CameraCatalogPage> createState() => _CameraCatalogPageState();
}

class _CameraCatalogPageState extends State<CameraCatalogPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final cameras = store.cameras
        .where(
          (camera) =>
              '${camera.name} ${camera.host}'.toLowerCase().contains(_query),
        )
        .toList();
    return PageFrame.slivers(
      title: 'Câmeras',
      subtitle: 'Seus dispositivos, imagens e conexões em um só lugar.',
      actions: [
        OutlinedButton.icon(
          onPressed: () => GlobalConnectionPage.open(context),
          icon: const Icon(Icons.settings_ethernet),
          label: const Text('Conexão global'),
        ),
        FilledButton.icon(
          onPressed: () => _edit(context),
          icon: const Icon(Icons.add),
          label: const Text('Adicionar câmera'),
        ),
      ],
      slivers: [
        const SliverToBoxAdapter(child: NetworkCameraDiscovery()),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: TextField(
              onChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
              decoration: InputDecoration(
                labelText: 'Buscar câmera ou IP',
                prefixIcon: const Icon(Icons.search),
                suffixText: '${cameras.length} câmeras',
              ),
            ),
          ),
        ),
        if (store.cameras.isEmpty)
          SliverToBoxAdapter(
            child: EmptyPanel(
              icon: Icons.videocam_outlined,
              title: 'Nenhuma câmera cadastrada',
              description:
                  'Adicione uma câmera IP para começar a montar seu monitor.',
              action: FilledButton.icon(
                onPressed: () => _edit(context),
                icon: const Icon(Icons.add),
                label: const Text('Adicionar câmera'),
              ),
            ),
          )
        else if (cameras.isEmpty)
          const SliverToBoxAdapter(
            child: EmptyPanel(
              icon: Icons.search_off,
              title: 'Nenhuma câmera encontrada',
              description: 'Tente buscar por outro nome ou endereço IP.',
            ),
          )
        else
          SliverLayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.crossAxisExtent >= 900
                  ? 3
                  : constraints.crossAxisExtent >= 580
                  ? 2
                  : 1;
              return SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _CameraCard(
                    camera: cameras[index],
                    onEdit: () => _edit(context, cameras[index]),
                    onClone: () => _clone(context, store, cameras[index]),
                    onDelete: () => _delete(context, store, cameras[index]),
                  ),
                  childCount: cameras.length,
                ),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  mainAxisExtent:
                      MediaQuery.textScalerOf(context).scale(14) > 20
                      ? 340
                      : 280,
                ),
              );
            },
          ),
      ],
    );
  }

  Future<void> _clone(
    BuildContext context,
    AppStore store,
    CameraDevice camera,
  ) async {
    final cloned = await CloneCameraDialog.show(
      context,
      camera: camera,
      store: store,
    );
    if (cloned == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Câmera “${camera.name}” clonada com sucesso.')),
      );
    }
  }

  Future<void> _edit(BuildContext context, [CameraDevice? camera]) async {
    final store = AppScope.of(context);
    final password = camera == null
        ? ''
        : await store.specificPasswordFor(camera);
    final globalPassword = await store.networkDiscoveryPassword();
    if (!context.mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => CameraEditorDialog(
        camera: camera,
        password: password,
        globalPassword: globalPassword,
        store: store,
      ),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Câmera salva com segurança.')),
      );
    }
  }

  Future<void> _delete(
    BuildContext context,
    AppStore store,
    CameraDevice camera,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover câmera?'),
        content: Text(
          '“${camera.name}” será removida do dispositivo e dos layouts.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmed == true) await store.removeCamera(camera.id);
  }
}

class _CameraCard extends StatelessWidget {
  const _CameraCard({
    required this.camera,
    required this.onEdit,
    required this.onClone,
    required this.onDelete,
  });
  final CameraDevice camera;
  final VoidCallback onEdit;
  final VoidCallback onClone;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                CameraThumbnail(cameraId: camera.id),
                Center(
                  child: IconButton.filled(
                    onPressed: () =>
                        CameraPreviewDialog.openSaved(context, store, camera),
                    tooltip: 'Ver vídeo de ${camera.name}',
                    icon: const Icon(Icons.play_arrow),
                  ),
                ),
                const Positioned(
                  left: 12,
                  bottom: 8,
                  child: Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text('Prévia da câmera'),
                    avatar: Icon(Icons.photo_outlined, size: 16),
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            title: Text(
              camera.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              camera.host,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: onEdit,
            trailing: PopupMenuButton<String>(
              tooltip: 'Opções da câmera',
              onSelected: (value) => switch (value) {
                'edit' => onEdit(),
                'clone' => onClone(),
                'delete' => onDelete(),
                _ => null,
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Editar câmera')),
                PopupMenuItem(value: 'clone', child: Text('Clonar câmera')),
                PopupMenuItem(value: 'delete', child: Text('Remover')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

