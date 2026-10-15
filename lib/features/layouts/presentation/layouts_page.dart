import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/state/app_store.dart';
import '../../camera_catalog/presentation/camera_picker.dart';
import '../../camera_catalog/presentation/camera_thumbnail.dart';
import '../../../shared/design_system/page_frame.dart';
import '../domain/layout_geometry.dart';
import '../domain/layout_preset.dart';
import '../domain/saved_monitor_profile.dart';
import 'widgets/layout_preset_picker.dart';

class LayoutsPage extends StatelessWidget {
  const LayoutsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final layout = store.activeLayout;
    return PageFrame(
      title: 'Layouts',
      subtitle: 'Escolha a grade e associe câmeras a cada posição.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutPresetPicker(
            selectedId: layout.id,
            onSelected: store.setLayout,
          ),
          const SizedBox(height: 18),
          _SavedProfiles(
            profiles: store.config.monitorProfiles,
            onSave: () => _saveProfile(context, store),
            onApply: store.applyMonitorProfile,
            onRemove: store.removeMonitorProfile,
          ),
          const SizedBox(height: 18),
          _MonitorPreview(
            layout: layout,
            slotCameraIds: store.config.slotCameraIds,
            cameraNames: {
              for (final camera in store.cameras) camera.id: camera.name,
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Câmeras na grade',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          if (store.cameras.isEmpty)
            const EmptyPanel(
              icon: Icons.videocam_outlined,
              title: 'Adicione câmeras primeiro',
              description:
                  'Depois você poderá selecionar uma câmera para cada posição da grade.',
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 900 ? 2 : 1;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: layout.cameraCount,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 8,
                    mainAxisExtent: 76,
                  ),
                  itemBuilder: (context, index) {
                    final selected = index < store.config.slotCameraIds.length
                        ? store.config.slotCameraIds[index]
                        : null;
                    final camera = store.cameras
                        .where((item) => item.id == selected)
                        .firstOrNull;
                    return _CameraSlotCard(
                      position: index + 1,
                      cameraName: camera?.name,
                      cameraId: camera?.id,
                      cameraDetail: camera == null
                          ? null
                          : '${camera.host}:${camera.effectivePort(store.config.defaultPort)} · ${camera.mainPath}',
                      onTap: () =>
                          _selectCamera(context, store, index, selected),
                    );
                  },
                );
              },
            ),
          const SizedBox(height: 12),
          if (layout.id != 'GRID_ALL')
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: store.clearSlots,
                icon: const Icon(Icons.clear_all),
                label: const Text('Limpar grade'),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _selectCamera(
    BuildContext context,
    AppStore store,
    int slotIndex,
    String? selectedId,
  ) async {
    final selection = await showModalBottomSheet<_SlotSelection>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 760),
      builder: (context) => CameraPicker(
        store: store,
        position: slotIndex + 1,
        selectedId: selectedId,
        onSelected: (id) => Navigator.pop(context, _SlotSelection(id)),
      ),
    );
    if (selection != null) await store.setSlot(slotIndex, selection.cameraId);
  }

  Future<void> _saveProfile(BuildContext context, AppStore store) async {
    final controller = TextEditingController();
    var startupSection = store.config.startupSection;
    final selection = await showDialog<(String, String)?>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Salvar perfil do monitor'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    maxLength: 60,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Nome do perfil',
                      hintText: 'Ex.: Portaria · noite',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: startupSection,
                    decoration: const InputDecoration(
                      labelText: 'Tela ao iniciar o aplicativo',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'auto',
                        child: Text('Automático'),
                      ),
                      DropdownMenuItem(
                        value: 'last',
                        child: Text('Última tela usada'),
                      ),
                      DropdownMenuItem(
                        value: 'dashboard',
                        child: Text('Início'),
                      ),
                      DropdownMenuItem(
                        value: 'monitor',
                        child: Text('Monitor'),
                      ),
                      DropdownMenuItem(
                        value: 'cameras',
                        child: Text('Câmeras'),
                      ),
                      DropdownMenuItem(
                        value: 'layouts',
                        child: Text('Layouts'),
                      ),
                      DropdownMenuItem(
                        value: 'settings',
                        child: Text('Ajustes'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => startupSection = value);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(context, (controller.text, startupSection)),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (selection == null) return;
    final saved = await store.saveMonitorProfile(
      name: selection.$1,
      startupSection: selection.$2,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved ? 'Perfil salvo.' : store.message ?? 'Não foi possível salvar.',
        ),
      ),
    );
  }
}

class _SlotSelection {
  const _SlotSelection(this.cameraId);

  final String? cameraId;
}

class _CameraSlotCard extends StatelessWidget {
  const _CameraSlotCard({
    required this.position,
    required this.cameraName,
    required this.cameraDetail,
    required this.cameraId,
    required this.onTap,
  });

  final int position;
  final String? cameraName;
  final String? cameraDetail;
  final String? cameraId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              if (cameraId != null)
                SizedBox(
                  width: 64,
                  height: 48,
                  child: CameraThumbnail(cameraId: cameraId!),
                )
              else
                CircleAvatar(radius: 16, child: Text('$position')),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cameraName ?? 'Selecionar câmera',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: cameraName == null
                            ? colors.primary
                            : colors.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cameraDetail ?? 'Posição vazia',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavedProfiles extends StatelessWidget {
  const _SavedProfiles({
    required this.profiles,
    required this.onSave,
    required this.onApply,
    required this.onRemove,
  });

  final List<SavedMonitorProfile> profiles;
  final VoidCallback onSave;
  final ValueChanged<String> onApply;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final heading = Row(
                  children: [
                    const Icon(Icons.bookmarks_outlined),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Perfis do monitor',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            'Salve combinações de layout e câmeras para abrir depois.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
                final saveButton = Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _importProfiles(context, store),
                      icon: const Icon(Icons.file_open_outlined),
                      label: const Text('Importar'),
                    ),
                    OutlinedButton.icon(
                      onPressed: profiles.isEmpty
                          ? null
                          : () => _exportProfiles(context, store),
                      icon: const Icon(Icons.ios_share_outlined),
                      label: const Text('Exportar'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: onSave,
                      icon: const Icon(Icons.bookmark_add_outlined),
                      label: const Text('Salvar perfil atual'),
                    ),
                  ],
                );
                if (constraints.maxWidth < 1060 ||
                    MediaQuery.textScalerOf(context).scale(14) > 20) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [heading, const SizedBox(height: 12), saveButton],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: heading),
                    const SizedBox(width: 12),
                    saveButton,
                  ],
                );
              },
            ),
            if (profiles.isEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Ainda não há perfis salvos. Atribua as câmeras abaixo e salve esta visualização.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ] else ...[
              const SizedBox(height: 12),
              for (final profile in profiles)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.dashboard_customize_outlined),
                  title: Text(profile.name),
                  subtitle: Text(
                    '${LayoutPreset.byId(profile.layoutId).name} · ${profile.slotCameraIds.whereType<String>().length} câmeras · início: ${_startupLabel(profile.startupSection)}',
                  ),
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      IconButton.filledTonal(
                        tooltip: 'Abrir perfil',
                        onPressed: () => onApply(profile.id),
                        icon: const Icon(Icons.play_arrow),
                      ),
                      IconButton(
                        tooltip: 'Remover perfil',
                        onPressed: () => onRemove(profile.id),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                  onTap: () => onApply(profile.id),
                ),
            ],
            if (store.message != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  store.message!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportProfiles(BuildContext context, AppStore store) async {
    final messenger = ScaffoldMessenger.of(context);
    final content = store.exportMonitorProfiles();
    final now = DateTime.now();
    final filename =
        'rtsp-hub-perfis-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.json';
    try {
      String? path;
      if (!kIsWeb &&
          (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
        path = (await getSaveLocation(
          acceptedTypeGroups: const [
            XTypeGroup(label: 'Perfis RTSP Hub', extensions: ['json']),
          ],
          suggestedName: filename,
        ))?.path;
        if (path == null) return;
      } else if (!kIsWeb && Platform.isAndroid) {
        final directory = await getDirectoryPath(
          confirmButtonText: 'Salvar perfis nesta pasta',
        );
        if (directory == null) return;
        path = '$directory${Platform.pathSeparator}$filename';
      }
      if (path == null) {
        await Clipboard.setData(ClipboardData(text: content));
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Perfis copiados para a área de transferência.'),
          ),
        );
        return;
      }
      await File(path).writeAsString(content, flush: true);
      messenger.showSnackBar(
        SnackBar(content: Text('Perfis exportados para $path.')),
      );
    } on Object {
      await Clipboard.setData(ClipboardData(text: content));
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível salvar o arquivo; os perfis foram copiados.',
          ),
        ),
      );
    }
  }

  Future<void> _importProfiles(BuildContext context, AppStore store) async {
    final messenger = ScaffoldMessenger.of(context);
    String? source;
    try {
      final file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(label: 'Perfis RTSP Hub', extensions: ['json']),
        ],
      );
      if (file == null) return;
      if (await file.length() > 5 * 1024 * 1024) {
        messenger.showSnackBar(
          const SnackBar(content: Text('O arquivo excede o limite de 5 MB.')),
        );
        return;
      }
      source = await file.readAsString();
    } on Object {
      source = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    }
    if (source == null || source.isEmpty) return;
    final added = await store.importMonitorProfiles(source);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          added == null || added == 0
              ? store.message ?? 'Não foi possível importar os perfis.'
              : '$added perfis importados. Confira as senhas das câmeras neste dispositivo.',
        ),
      ),
    );
  }

  String _startupLabel(String value) => switch (value) {
    'last' => 'última tela',
    'monitor' => 'monitor',
    'cameras' => 'câmeras',
    'layouts' => 'layouts',
    'settings' => 'ajustes',
    'dashboard' => 'início',
    _ => 'automático',
  };
}

class _MonitorPreview extends StatelessWidget {
  const _MonitorPreview({
    required this.layout,
    required this.slotCameraIds,
    required this.cameraNames,
  });

  final LayoutPreset layout;
  final List<String?> slotCameraIds;
  final Map<String, String> cameraNames;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.monitor, color: colors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Prévia do monitor',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        'Miniaturas salvas. Toque nas posições abaixo para escolher as câmeras.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${layout.cameraCount} posições',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final size = Size(
                        constraints.maxWidth,
                        constraints.maxHeight,
                      );
                      final customTiles = LayoutGeometry.tiles(layout.id, size);
                      return DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFF080D16),
                          border: Border.all(color: colors.outlineVariant),
                        ),
                        child: Stack(
                          children: [
                            for (
                              var index = 0;
                              index < layout.cameraCount;
                              index++
                            )
                              Positioned.fromRect(
                                rect: _tileRect(
                                  index,
                                  size,
                                  customTiles,
                                ).deflate(1.5),
                                child: _MonitorPreviewTile(
                                  number: index + 1,
                                  cameraName: _cameraName(index),
                                  cameraId: index < slotCameraIds.length
                                      ? slotCameraIds[index]
                                      : null,
                                  emphasized: layout.focusIndex == index,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _cameraName(int index) {
    if (index >= slotCameraIds.length) return null;
    final id = slotCameraIds[index];
    return id == null ? null : cameraNames[id];
  }

  Rect _tileRect(int index, Size size, List<Rect> customTiles) {
    if (customTiles.length == layout.cameraCount) return customTiles[index];
    final width = size.width / layout.columns;
    final height = size.height / layout.rows;
    final row = index ~/ layout.columns;
    final column = index % layout.columns;
    return Rect.fromLTWH(column * width, row * height, width, height);
  }
}

class _MonitorPreviewTile extends StatelessWidget {
  const _MonitorPreviewTile({
    required this.number,
    required this.cameraName,
    required this.emphasized,
    required this.cameraId,
  });

  final int number;
  final String? cameraName;
  final bool emphasized;
  final String? cameraId;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111A28),
        border: Border.all(
          color: emphasized ? colors.primary : const Color(0xFF293548),
          width: emphasized ? 2 : 1,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.maxWidth < 90 || constraints.maxHeight < 46;
          return Stack(
            children: [
              if (cameraId != null) ...[
                Positioned.fill(child: CameraThumbnail(cameraId: cameraId!)),
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xB3000000), Color(0x00000000)],
                      ),
                    ),
                  ),
                ),
              ],
              if (!compact && cameraId == null)
                Center(
                  child: Icon(
                    cameraName == null
                        ? Icons.videocam_off_outlined
                        : Icons.videocam_outlined,
                    color: Colors.white.withValues(alpha: 0.28),
                    size: 24,
                  ),
                ),
              Positioned(
                left: 5,
                top: 4,
                right: 4,
                child: Text(
                  cameraName == null
                      ? '$number · Vazia'
                      : '$number · $cameraName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cameraName == null ? Colors.white60 : Colors.white,
                    fontSize: compact ? 8 : 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (emphasized && constraints.maxHeight > 46)
                Positioned(
                  right: 5,
                  bottom: 4,
                  child: Icon(Icons.star, color: colors.primary, size: 12),
                ),
            ],
          );
        },
      ),
    );
  }
}
