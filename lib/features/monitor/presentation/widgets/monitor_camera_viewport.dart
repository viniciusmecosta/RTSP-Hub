import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../../../layouts/domain/freeform_slot.dart';
import '../../../../shared/design_system/app_motion.dart';
import '../../../layouts/domain/layout_geometry.dart';
import '../../../layouts/domain/layout_preset.dart';

class MonitorCameraViewport extends StatefulWidget {
  const MonitorCameraViewport({
    required this.layout,
    required this.children,
    required this.pageStart,
    this.freeformSlots = const [],
    this.focusedIndex,
    this.onVisibleSlotsChanged,
    super.key,
  });

  final LayoutPreset layout;
  final List<Widget> children;
  final int pageStart;
  final List<FreeformSlot> freeformSlots;
  final int? focusedIndex;
  final ValueChanged<Set<int>>? onVisibleSlotsChanged;

  @override
  State<MonitorCameraViewport> createState() => _MonitorCameraViewportState();
}

class _MonitorCameraViewportState extends State<MonitorCameraViewport> {
  final _scrollController = ScrollController(keepScrollOffset: false);
  Set<int> _lastVisible = {};
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (mounted) setState(() {});
  }

  double _gridOffset = 0;
  int _scrollRevision = 0;

  @override
  void didUpdateWidget(MonitorCameraViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    final pageChanged =
        oldWidget.pageStart != widget.pageStart ||
        oldWidget.layout.id != widget.layout.id;
    if (pageChanged) {
      _gridOffset = 0;
      _restoreScroll(0);
    } else if (oldWidget.focusedIndex == null && widget.focusedIndex != null) {
      _gridOffset = _scrollController.hasClients ? _scrollController.offset : 0;
      _restoreScroll(0);
    } else if (oldWidget.focusedIndex != null && widget.focusedIndex == null) {
      _restoreScroll(_gridOffset);
    }
  }

  void _restoreScroll(double offset) {
    final revision = ++_scrollRevision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          revision != _scrollRevision ||
          !_scrollController.hasClients) {
        return;
      }
      _scrollController.jumpTo(
        offset.clamp(0, _scrollController.position.maxScrollExtent),
      );
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final canvas = constraints.biggest;
      final count = widget.children.length;
      if (count == 0) return const SizedBox.shrink();
      final focused = widget.focusedIndex;
      final hasFocus = focused != null && focused >= 0 && focused < count;
      List<Rect> rectangles = const [];
      var contentHeight = canvas.height;
      if (widget.layout.id == 'FREEFORM') {
        final slots = widget.freeformSlots.isEmpty
            ? const [FreeformSlot(x: 0, y: 0, width: 1, height: 1)]
            : widget.freeformSlots.skip(widget.pageStart).take(count).toList();
        rectangles = LayoutGeometry.freeformTiles(slots, canvas);
      } else if (widget.layout.focusIndex != null &&
          canvas.width >= 600 &&
          widget.pageStart == 0 &&
          count == widget.layout.cameraCount) {
        rectangles = LayoutGeometry.tiles(widget.layout.id, canvas);
      }
      if (rectangles.length != count) {
        final columns = LayoutGeometry.bestColumns(
          layout: widget.layout,
          canvas: canvas,
          visibleCount: count,
        );
        final rows = (count / columns).ceil();
        const spacing = 3.0;
        const padding = 3.0;
        final width =
            max(1.0, canvas.width - padding * 2 - spacing * (columns - 1)) /
            columns;
        final height =
            max(1.0, canvas.height - padding * 2 - spacing * (rows - 1)) / rows;
        final scrolls =
            canvas.width < 600 &&
            rows *
                    ((canvas.width / columns) /
                        LayoutGeometry.cameraAspectRatio) >
                canvas.height;
        final cellHeight = scrolls
            ? width / LayoutGeometry.cameraAspectRatio
            : height;
        contentHeight = max(
          canvas.height,
          padding * 2 + rows * cellHeight + spacing * (rows - 1),
        );
        rectangles = [
          for (var index = 0; index < count; index++)
            Rect.fromLTWH(
              padding + (index % columns) * (width + spacing),
              padding + (index ~/ columns) * (cellHeight + spacing),
              width,
              cellHeight,
            ),
        ];
      } else {
        rectangles = [for (final rect in rectangles) rect.deflate(1.5)];
      }
      if (widget.onVisibleSlotsChanged != null) {
        final offset = _scrollController.hasClients
            ? _scrollController.offset
            : 0.0;
        final visibleArea = Rect.fromLTWH(
          0,
          offset,
          canvas.width,
          canvas.height,
        );
        final visible = <int>{
          for (var i = 0; i < count; i++)
            if (hasFocus ? i == focused : rectangles[i].overlaps(visibleArea))
              widget.pageStart + i,
        };
        if (visible.length != _lastVisible.length ||
            !visible.containsAll(_lastVisible)) {
          _lastVisible = visible;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) widget.onVisibleSlotsChanged?.call(visible);
          });
        }
      }
      return SingleChildScrollView(
        controller: _scrollController,
        physics: !hasFocus && contentHeight > canvas.height
            ? const ClampingScrollPhysics()
            : const NeverScrollableScrollPhysics(),
        child: SizedBox(
          width: canvas.width,
          height: hasFocus ? canvas.height : contentHeight,
          child: Stack(
            children: [
              for (var index = 0; index < count; index++)
                AnimatedPositioned.fromRect(
                  duration: AppMotion.reduced(context)
                      ? Duration.zero
                      : AppMotion.focusDuration,
                  curve: Curves.easeInOutCubic,
                  key: ValueKey((
                    'camera-position',
                    widget.children[index].key,
                  )),
                  rect: hasFocus && index == focused
                      ? Offset.zero & canvas
                      : rectangles[index],
                  child: TickerMode(
                    enabled: !hasFocus || index == focused,
                    child: ExcludeFocus(
                      excluding: hasFocus && index != focused,
                      child: Offstage(
                        offstage: hasFocus && index != focused,
                        child: RepaintBoundary(child: widget.children[index]),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}
