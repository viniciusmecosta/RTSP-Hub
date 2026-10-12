import 'package:flutter/material.dart';

import '../../../app/state/app_store.dart';
import '../../../shared/design_system/page_frame.dart';
import '../domain/layout_geometry.dart';
import '../domain/layout_preset.dart';
import '../domain/saved_monitor_profile.dart';

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
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final preset in LayoutPreset.all)
                    ChoiceChip(
                      label: Text(preset.name),
                      selected: preset.id == layout.id,
                      onSelected: (_) => store.setLayout(preset.id),
                    ),
                ],
              ),
            ),
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
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 15,
                              child: Text('${index + 1}'),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String?>(
                                  isExpanded: true,
                                  value: selected,
                                  hint: const Text('Posição vazia'),
                                  items: [
                                    const DropdownMenuItem<String?>(
                                      value: null,
                                      child: Text('Não atribuir câmera'),
                                    ),
                                    for (final camera in store.cameras)
                                      DropdownMenuItem(
                                        value: camera.id,
                                        child: Text(
                                          camera.name,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                  ],
                                  onChanged: (id) => store.setSlot(index, id),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          const SizedBox(height: 12),
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

  Future<void> _saveProfile(BuildContext context, AppStore store) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Salvar perfil do monitor'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 60,
          textInputAction: TextInputAction.done,
          onSubmitted: (value) => Navigator.pop(context, value),
          decoration: const InputDecoration(
            labelText: 'Nome do perfil',
            hintText: 'Ex.: Loja · horário comercial',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null) return;
    final saved = await store.saveMonitorProfile(name: name);
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
            Row(
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
                FilledButton.tonalIcon(
                  onPressed: onSave,
                  icon: const Icon(Icons.bookmark_add_outlined),
                  label: const Text('Salvar perfil atual'),
                ),
              ],
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
                    '${LayoutPreset.byId(profile.layoutId).name} · ${profile.slotCameraIds.whereType<String>().length} câmeras',
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
                        'Visualização aproximada da grade. Não inicia transmissões.',
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
  });

  final int number;
  final String? cameraName;
  final bool emphasized;

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
              if (!compact)
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
