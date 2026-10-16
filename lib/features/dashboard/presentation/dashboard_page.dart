import 'dart:math';

import 'package:flutter/material.dart';

import '../../../app/state/app_store.dart';
import '../../../shared/design_system/page_frame.dart';
import '../../camera_catalog/presentation/camera_preview_dialog.dart';
import '../../camera_catalog/presentation/widgets/camera_preview_card.dart';
import '../../settings/presentation/global_connection_page.dart';

class DashboardPage extends StatefulWidget {
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
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _applyingProfile = false;

  Future<void> _selectProfile(String? id) async {
    if (id == null || _applyingProfile) return;
    final store = AppScope.of(context);
    setState(() => _applyingProfile = true);
    final applied = await store.applyMonitorProfile(id);
    if (!mounted) return;
    setState(() => _applyingProfile = false);
    if (!applied) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(store.message ?? 'Não foi possível abrir o perfil.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final colors = Theme.of(context).colorScheme;
    final profile = store.lastSavedProfile;
    final selected = store.config.slotCameraIds.whereType<String>().length;
    final cameras = store.cameras.take(4).toList(growable: false);
    final wideHeader =
        MediaQuery.sizeOf(context).width >= 1000 &&
        MediaQuery.textScalerOf(context).scale(14) <= 20;
    final selector = DropdownButtonFormField<String>(
      key: ValueKey(store.config.lastProfileId),
      initialValue:
          store.config.monitorProfiles.any(
            (item) => item.id == store.config.lastProfileId,
          )
          ? store.config.lastProfileId
          : null,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Perfil de visualização',
        hintText: 'Grade atual',
        prefixIcon: Icon(Icons.home_outlined),
      ),
      items: [
        for (final item in store.config.monitorProfiles)
          DropdownMenuItem(
            value: item.id,
            child: Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: _applyingProfile || store.config.monitorProfiles.isEmpty
          ? null
          : _selectProfile,
      hint: const Text('Grade atual'),
    );
    final open = FilledButton.icon(
      onPressed: _applyingProfile
          ? null
          : store.cameras.isEmpty
          ? widget.onAddCamera
          : selected == 0
          ? widget.onOpenLayouts ?? widget.onOpenMonitor
          : widget.onOpenMonitor,
      icon: Icon(store.cameras.isEmpty ? Icons.add : Icons.monitor_outlined),
      label: Text(
        store.cameras.isEmpty
            ? 'Adicionar câmera'
            : selected == 0
            ? 'Montar monitor'
            : 'Abrir monitor',
      ),
    );
    return PageFrame.slivers(
      title: 'Visão geral',
      subtitle: 'Suas câmeras, em um olhar.',
      maxContentWidth: 1200,
      actions: [
        if (wideHeader) ...[
          SizedBox(width: 220, child: selector),
          SizedBox(width: 180, child: open),
        ],
      ],
      slivers: [
        SliverToBoxAdapter(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact =
                  constraints.maxWidth < 620 ||
                  MediaQuery.textScalerOf(context).scale(14) > 20;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!wideHeader && compact) ...[
                    selector,
                    const SizedBox(height: 14),
                    open,
                  ] else if (!wideHeader)
                    Row(
                      children: [
                        Expanded(child: selector),
                        const SizedBox(width: 16),
                        SizedBox(width: 200, child: open),
                      ],
                    ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 16,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '${store.cameras.length} câmeras cadastradas · $selected na grade',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      if (profile != null && widget.onOpenProfile != null)
                        TextButton.icon(
                          onPressed: _applyingProfile
                              ? null
                              : () => widget.onOpenProfile!(profile.id),
                          icon: const Icon(Icons.history_rounded, size: 18),
                          label: Text(
                            'Acesso rápido · ${profile.name}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],
              );
            },
          ),
        ),
        SliverToBoxAdapter(
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Suas câmeras',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              TextButton(
                onPressed: widget.onAddCamera,
                child: const Text('Ver todas'),
              ),
            ],
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 10)),
        if (cameras.isEmpty)
          SliverToBoxAdapter(
            child: EmptyPanel(
              icon: Icons.videocam_outlined,
              title: 'Sua primeira câmera começa aqui',
              description:
                  'Defina a conexão global e cadastre um IP ou encontre as câmeras da sua rede.',
              action: FilledButton.icon(
                onPressed: widget.onAddCamera,
                icon: const Icon(Icons.add),
                label: const Text('Adicionar câmera'),
              ),
            ),
          )
        else
          SliverLayoutBuilder(
            builder: (context, constraints) {
              final scaler = MediaQuery.textScalerOf(context);
              final columns =
                  constraints.crossAxisExtent < 300 ||
                      scaler.scale(14) > 20 && constraints.crossAxisExtent < 650
                  ? 1
                  : 2;
              final width =
                  (constraints.crossAxisExtent - 14 * (columns - 1)) / columns;
              return SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  mainAxisExtent: min(
                    constraints.crossAxisExtent >= 600
                        ? max(
                            180,
                            (MediaQuery.sizeOf(context).height - 400) / 2,
                          )
                        : double.infinity,
                    CameraPreviewCard.heightFor(
                      width,
                      scaler,
                      showHost: false,
                      imageAspectRatio: constraints.crossAxisExtent >= 600
                          ? 2.8
                          : 16 / 9,
                    ),
                  ),
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => CameraPreviewCard(
                    key: ValueKey(cameras[index].id),
                    camera: cameras[index],
                    showHost: false,
                    onPreview: () => CameraPreviewDialog.openSaved(
                      context,
                      store,
                      cameras[index],
                    ),
                  ),
                  childCount: cameras.length,
                ),
              );
            },
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 24),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 600;
                final columns =
                    constraints.maxWidth < 300 ||
                        MediaQuery.textScalerOf(context).scale(14) > 20 &&
                            compact
                    ? 1
                    : 2;
                final width =
                    (constraints.maxWidth - 14 * (columns - 1)) / columns;
                return Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    SizedBox(
                      width: width,
                      child: _DashboardAction(
                        title: 'Layouts',
                        description: compact
                            ? null
                            : 'Organize as câmeras e salve seus perfis.',
                        icon: Icons.grid_view_outlined,
                        onTap: widget.onOpenLayouts ?? widget.onOpenMonitor,
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _DashboardAction(
                        title: 'Conexão global',
                        description: compact
                            ? null
                            : 'Usuário, senha, porta e canais padrão.',
                        icon: Icons.settings_ethernet,
                        onTap: () => GlobalConnectionPage.open(context),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _DashboardAction extends StatelessWidget {
  const _DashboardAction({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String? description;
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
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(icon, color: colors.primary),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    if (description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        description!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
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
