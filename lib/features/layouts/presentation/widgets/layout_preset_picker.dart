import 'package:flutter/material.dart';

import '../../domain/layout_geometry.dart';
import '../../domain/layout_preset.dart';

class LayoutPresetPicker extends StatelessWidget {
  const LayoutPresetPicker({
    required this.selectedId,
    required this.onSelected,
    super.key,
  });

  final String selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final regular = LayoutPreset.all.where(
      (preset) => preset.focusIndex == null,
    );
    final focused = LayoutPreset.all.where(
      (preset) => preset.focusIndex != null,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Escolha a distribuição',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'A prévia mostra a posição dos vídeos. Você pode trocar de layout sem refazer o cadastro.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            _cards(context, regular),
            const SizedBox(height: 12),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(top: 8),
              initiallyExpanded: focused.any(
                (preset) => preset.id == selectedId,
              ),
              title: const Text('Layouts com câmera em destaque'),
              subtitle: const Text('Uma ou mais câmeras maiores na grade'),
              children: [_cards(context, focused)],
            ),
          ],
        ),
      ),
    );
  }

  Widget _cards(BuildContext context, Iterable<LayoutPreset> presets) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 5
            : constraints.maxWidth >= 620
            ? 4
            : constraints.maxWidth >= 390
            ? 3
            : 2;
        const spacing = 10.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final preset in presets)
              SizedBox(
                width: width,
                child: _LayoutPresetCard(
                  preset: preset,
                  selected: preset.id == selectedId,
                  onTap: () => onSelected(preset.id),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _LayoutPresetCard extends StatelessWidget {
  const _LayoutPresetCard({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final LayoutPreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final background = selected
        ? colors.primaryContainer
        : colors.surfaceContainerLow;
    final foreground = selected ? colors.onPrimaryContainer : colors.onSurface;
    return Semantics(
      button: true,
      selected: selected,
      label: preset.name,
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            color: selected ? colors.primary : colors.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 55,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _LayoutMiniaturePainter(
                      preset: preset,
                      background: colors.surface,
                      tile: selected ? colors.primary : colors.outline,
                    ),
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  preset.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: foreground,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LayoutMiniaturePainter extends CustomPainter {
  const _LayoutMiniaturePainter({
    required this.preset,
    required this.background,
    required this.tile,
  });

  final LayoutPreset preset;
  final Color background;
  final Color tile;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bounds, const Radius.circular(6)),
      Paint()..color = background,
    );
    final special = LayoutGeometry.tiles(preset.id, size);
    final rows = preset.id == 'GRID_ALL' ? 2 : preset.rows;
    final columns = preset.id == 'GRID_ALL' ? 2 : preset.columns;
    final rects = special.isNotEmpty
        ? special
        : [
            for (var index = 0; index < rows * columns; index++)
              Rect.fromLTWH(
                (index % columns) * size.width / columns,
                (index ~/ columns) * size.height / rows,
                size.width / columns,
                size.height / rows,
              ),
          ];
    final paint = Paint()..color = tile;
    for (final rect in rects) {
      final inset = rect.deflate(2);
      if (inset.isEmpty) continue;
      canvas.drawRRect(
        RRect.fromRectAndRadius(inset, const Radius.circular(2)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LayoutMiniaturePainter oldDelegate) =>
      oldDelegate.preset.id != preset.id ||
      oldDelegate.background != background ||
      oldDelegate.tile != tile;
}
