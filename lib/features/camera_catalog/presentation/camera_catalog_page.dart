import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/state/app_store.dart';
import '../../../shared/design_system/page_frame.dart';
import '../../settings/presentation/global_connection_page.dart';
import '../domain/camera_device.dart';
import 'camera_editor_dialog.dart';
import 'camera_preview_dialog.dart';
import 'widgets/camera_preview_card.dart';
import 'clone_camera_dialog.dart';
import 'network_camera_discovery.dart';

class CameraCatalogPage extends StatefulWidget {
  const CameraCatalogPage({super.key});

  @override
  State<CameraCatalogPage> createState() => _CameraCatalogPageState();
}

class _CameraCatalogPageState extends State<CameraCatalogPage> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

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
              controller: _search,
              onChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
              decoration: InputDecoration(
                labelText: 'Buscar câmera ou IP',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpar busca',
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close),
                      ),
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
              final columns = constraints.crossAxisExtent >= 1040
                  ? 3
                  : constraints.crossAxisExtent >= 580
                  ? 2
                  : 1;
              return SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => CameraPreviewCard(
                    key: ValueKey(cameras[index].id),
                    onPreview: () => CameraPreviewDialog.openSaved(
                      context,
                      store,
                      cameras[index],
                    ),
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
                  mainAxisExtent: CameraPreviewCard.heightFor(
                    (constraints.crossAxisExtent - 14 * (columns - 1)) /
                        columns,
                    MediaQuery.textScalerOf(context),
                  ),
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
        SnackBar(content: Text(store.message ?? 'Câmera salva com segurança.')),
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
    if (confirmed == true) {
      await store.removeCamera(camera.id);
      if (context.mounted && store.message != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(store.message!)));
      }
    }
  }
}
