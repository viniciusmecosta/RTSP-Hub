import 'package:flutter/material.dart';

import '../../../app/state/app_store.dart';
import 'camera_preview_dialog.dart';
import 'camera_thumbnail.dart';

class CameraPicker extends StatefulWidget {
  const CameraPicker({
    required this.store,
    required this.position,
    required this.selectedId,
    required this.onSelected,
    super.key,
  });

  final AppStore store;
  final int position;
  final String? selectedId;
  final ValueChanged<String?> onSelected;

  @override
  State<CameraPicker> createState() => _CameraPickerState();
}

class _CameraPickerState extends State<CameraPicker> {
  String _query = '';

  String _positionLabel(String id) {
    final index = widget.store.config.slotCameraIds.indexOf(id);
    return index < 0 ? '' : ' • Mover da posição ${index + 1}';
  }

  @override
  Widget build(BuildContext context) {
    final cameras = widget.store.cameras
        .where(
          (camera) =>
              '${camera.name} ${camera.host}'.toLowerCase().contains(_query),
        )
        .toList();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.78,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Câmera da posição ${widget.position}',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          tooltip: 'Fechar seleção',
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const Text(
                      'Selecione pela imagem ou abra o vídeo para conferir.',
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      onChanged: (value) =>
                          setState(() => _query = value.trim().toLowerCase()),
                      decoration: const InputDecoration(
                        labelText: 'Buscar câmera ou IP',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  children: [
                    if (widget.store.activeLayout.id != 'GRID_ALL')
                      ListTile(
                        leading: const Icon(Icons.videocam_off_outlined),
                        title: const Text('Deixar posição vazia'),
                        selected: widget.selectedId == null,
                        onTap: () => widget.onSelected(null),
                      ),
                    if (cameras.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Nenhuma câmera encontrada. Tente outro nome ou IP.',
                        ),
                      ),
                    for (final camera in cameras)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          leading: SizedBox(
                            width: 72,
                            height: 54,
                            child: CameraThumbnail(cameraId: camera.id),
                          ),
                          title: Text(
                            camera.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            camera.id == widget.selectedId
                                ? '${camera.host}:${camera.effectivePort(widget.store.config.defaultPort)} • Selecionada'
                                : '${camera.host}:${camera.effectivePort(widget.store.config.defaultPort)}${_positionLabel(camera.id)}',
                            maxLines: 2,
                          ),
                          selected: camera.id == widget.selectedId,
                          onTap: () => widget.onSelected(camera.id),
                          trailing: IconButton(
                            tooltip: 'Ver vídeo de ${camera.name}',
                            icon: const Icon(Icons.play_circle_outline),
                            onPressed: () => CameraPreviewDialog.openSaved(
                              context,
                              widget.store,
                              camera,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
