import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class LayoutPreviewSlot extends StatelessWidget {
  const LayoutPreviewSlot({
    required this.index,
    required this.count,
    required this.onSelect,
    required this.onSwap,
    required this.child,
    super.key,
  });
  final int index;
  final int count;
  final VoidCallback onSelect;
  final ValueChanged<int> onSwap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final desktop = {
      TargetPlatform.linux,
      TargetPlatform.windows,
      TargetPlatform.macOS,
    }.contains(defaultTargetPlatform);
    return DragTarget<int>(
      onWillAcceptWithDetails: (details) =>
          details.data >= 0 && details.data < count && details.data != index,
      onAcceptWithDetails: (details) => onSwap(details.data),
      builder: (context, candidates, rejected) {
        final content = Material(
          color: Colors.transparent,
          child: InkWell(
            key: ValueKey('layout-preview-slot-$index'),
            onTap: onSelect,
            child: Stack(
              fit: StackFit.expand,
              children: [
                child,
                if (candidates.isNotEmpty)
                  IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: colors.primary, width: 3),
                      ),
                    ),
                  ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 64 ||
                        constraints.maxHeight < 44) {
                      return const SizedBox.shrink();
                    }
                    return Align(
                      alignment: Alignment.bottomRight,
                      child: PopupMenuButton<int>(
                        tooltip: 'Mover posição ${index + 1}',
                        icon: const Icon(Icons.swap_horiz, color: Colors.white),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black87,
                        ),
                        onSelected: onSwap,
                        itemBuilder: (_) => [
                          for (var target = 0; target < count; target++)
                            if (target != index)
                              PopupMenuItem(
                                value: target,
                                child: Text('Trocar com posição ${target + 1}'),
                              ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
        final feedback = Material(
          color: const Color(0xFF111A28),
          child: SizedBox(width: 160, height: 90, child: child),
        );
        final faded = Opacity(opacity: 0.35, child: content);
        if (desktop) {
          return Draggable<int>(
            data: index,
            dragAnchorStrategy: pointerDragAnchorStrategy,
            feedback: feedback,
            childWhenDragging: faded,
            child: content,
          );
        }
        return LongPressDraggable<int>(
          data: index,
          dragAnchorStrategy: pointerDragAnchorStrategy,
          feedback: feedback,
          childWhenDragging: faded,
          child: content,
        );
      },
    );
  }
}
