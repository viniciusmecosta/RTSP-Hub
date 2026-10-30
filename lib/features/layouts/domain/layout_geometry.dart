import 'dart:math';
import 'dart:ui';

import 'freeform_slot.dart';
import 'layout_preset.dart';

class LayoutGeometry {
  static const double cameraAspectRatio = 16 / 9;
  static const double maxAspectStretch = 1.32;

  static int bestColumns({
    required LayoutPreset layout,
    required Size canvas,
    required int visibleCount,
  }) {
    if (visibleCount <= 1) return 1;
    if (canvas.width < 600) {
      if (layout.id == 'GRID_2V') return 1;
      if (layout.id == 'GRID_2H' && canvas.width >= canvas.height) return 2;
      return _bestAutoColumns(
        visibleCount: visibleCount,
        canvas: canvas,
        maxColumns: 2,
      );
    }
    if (layout.id == 'GRID_ALL' || visibleCount < layout.cameraCount) {
      final ceiling = visibleCount < layout.cameraCount
          ? min(layout.columns, visibleCount)
          : min(6, visibleCount);
      return _bestAutoColumns(
        visibleCount: visibleCount,
        canvas: canvas,
        maxColumns: ceiling,
      );
    }
    if (canvas.width < 980) return layout.columns.clamp(1, 3);
    return layout.columns.clamp(1, 6);
  }

  static int _bestAutoColumns({
    required int visibleCount,
    required Size canvas,
    required int maxColumns,
  }) {
    final safeWidth = max(1.0, canvas.width);
    final safeHeight = max(1.0, canvas.height);
    var bestCols = 1;
    var bestScore = double.negativeInfinity;
    final limit = min(visibleCount, max(1, maxColumns));
    final isLandscape = safeWidth >= safeHeight;
    for (var cols = 1; cols <= limit; cols++) {
      final rows = (visibleCount + cols - 1) ~/ cols;
      final cellW = safeWidth / cols;
      final cellH = safeHeight / rows;
      final cellAspect = cellW / cellH;
      final distortion = max(
        cellAspect / cameraAspectRatio,
        cameraAspectRatio / cellAspect,
      );
      final emptySlots = rows * cols - visibleCount;
      final fillRatio = visibleCount / (rows * cols);
      final clampedDistortion = max(1.05, distortion);
      final overStretch = max(1.0, distortion / maxAspectStretch);
      final orientationBonus =
          (isLandscape && cols >= rows) || (!isLandscape && rows >= cols)
          ? 0.05
          : 0.0;
      final score =
          (fillRatio /
              (pow(clampedDistortion, 1.8) * overStretch * overStretch)) -
          (emptySlots * 0.02) +
          orientationBonus;
      if (score > bestScore) {
        bestScore = score;
        bestCols = cols;
      }
    }
    return bestCols;
  }

  static Size fittedVideoSize(
    Size cell, {
    required String fitMode,
    double targetAspectRatio = cameraAspectRatio,
  }) {
    final width = max(1.0, cell.width);
    final height = max(1.0, cell.height);
    if (fitMode == 'fill') return Size(width, height);
    final cellAspect = width / height;
    final containWidth = cellAspect >= targetAspectRatio
        ? height * targetAspectRatio
        : width;
    final containHeight = cellAspect >= targetAspectRatio
        ? height
        : width / targetAspectRatio;
    if (fitMode == 'contain') return Size(containWidth, containHeight);
    // Smart mode ('smart'): stretches up to maxAspectStretch along the wider axis
    // so cameras occupy maximum space without excessive distortion.
    if (cellAspect > targetAspectRatio) {
      final stretchedWidth = min(width, containWidth * maxAspectStretch);
      return Size(stretchedWidth, height);
    } else {
      final stretchedHeight = min(height, containHeight * maxAspectStretch);
      return Size(width, stretchedHeight);
    }
  }

  static List<Rect> freeformTiles(List<FreeformSlot> slots, Size size) {
    if (slots.isEmpty) return const [];
    return [for (final slot in slots) slot.toRect(size)];
  }

  static List<FreeformSlot> autoArrangeFreeform(List<FreeformSlot> slots) {
    if (slots.isEmpty) return const [];
    final count = slots.length;
    if (count == 1) {
      return [slots[0].copyWith(x: 0, y: 0, width: 1.0, height: 1.0)];
    }
    if (count == 2) {
      return [
        slots[0].copyWith(x: 0, y: 0, width: 0.5, height: 1.0),
        slots[1].copyWith(x: 0.5, y: 0, width: 0.5, height: 1.0),
      ];
    }
    if (count == 3) {
      return [
        slots[0].copyWith(x: 0, y: 0, width: 0.67, height: 1.0),
        slots[1].copyWith(x: 0.67, y: 0, width: 0.33, height: 0.5),
        slots[2].copyWith(x: 0.67, y: 0.5, width: 0.33, height: 0.5),
      ];
    }
    final cols = sqrt(count).ceil();
    final rows = (count + cols - 1) ~/ cols;
    final w = 1.0 / cols;
    final h = 1.0 / rows;
    final result = <FreeformSlot>[];
    for (var i = 0; i < count; i++) {
      final col = i % cols;
      final row = i ~/ cols;
      result.add(
        slots[i].copyWith(x: col * w, y: row * h, width: w, height: h),
      );
    }
    return result;
  }

  static List<Rect> tiles(String id, Size size) {
    final unit = switch (id) {
      'FOCUS_RIGHT_3' => _focusRightThree,
      'FOCUS_LEFT_3' => _focusLeftThree,
      'FOCUS_BASE_RIGHT_5' => _focusBaseRightFive,
      'FOCUS_LEFT_7' => _focusLeftSeven,
      'FOCUS_BASE_RIGHT_8' => _focusBaseRightEight,
      'DUAL_FOCUS_6' => _dualFocusSix,
      'DUAL_FOCUS_8' => _dualFocusEight,
      'CENTER_FOCUS_12' => _centerFocusTwelve,
      'TRIPLE_FOCUS_9' => _tripleFocusNine,
      _ => const <Rect>[],
    };
    return [
      for (final rect in unit)
        Rect.fromLTWH(
          rect.left * size.width,
          rect.top * size.height,
          rect.width * size.width,
          rect.height * size.height,
        ),
    ];
  }

  static const _focusRightThree = [
    Rect.fromLTWH(0, 0, 2 / 3, 1),
    Rect.fromLTWH(2 / 3, 0, 1 / 3, 1 / 3),
    Rect.fromLTWH(2 / 3, 1 / 3, 1 / 3, 1 / 3),
    Rect.fromLTWH(2 / 3, 2 / 3, 1 / 3, 1 / 3),
  ];

  static const _focusLeftThree = [
    Rect.fromLTWH(1 / 3, 0, 2 / 3, 1),
    Rect.fromLTWH(0, 0, 1 / 3, 1 / 3),
    Rect.fromLTWH(0, 1 / 3, 1 / 3, 1 / 3),
    Rect.fromLTWH(0, 2 / 3, 1 / 3, 1 / 3),
  ];

  static const _focusBaseRightFive = [
    Rect.fromLTWH(0, 0, 2 / 3, 2 / 3),
    Rect.fromLTWH(2 / 3, 0, 1 / 3, 1 / 3),
    Rect.fromLTWH(2 / 3, 1 / 3, 1 / 3, 1 / 3),
    Rect.fromLTWH(0, 2 / 3, 1 / 3, 1 / 3),
    Rect.fromLTWH(1 / 3, 2 / 3, 1 / 3, 1 / 3),
    Rect.fromLTWH(2 / 3, 2 / 3, 1 / 3, 1 / 3),
  ];

  static const _focusLeftSeven = [
    Rect.fromLTWH(1 / 4, 0, 3 / 4, 3 / 4),
    Rect.fromLTWH(0, 0, 1 / 4, 1 / 4),
    Rect.fromLTWH(0, 1 / 4, 1 / 4, 1 / 4),
    Rect.fromLTWH(0, 2 / 4, 1 / 4, 1 / 4),
    Rect.fromLTWH(0, 3 / 4, 1 / 4, 1 / 4),
    Rect.fromLTWH(1 / 4, 3 / 4, 1 / 4, 1 / 4),
    Rect.fromLTWH(2 / 4, 3 / 4, 1 / 4, 1 / 4),
    Rect.fromLTWH(3 / 4, 3 / 4, 1 / 4, 1 / 4),
  ];

  static const _focusBaseRightEight = [
    Rect.fromLTWH(0, 0, 3 / 5, 3 / 5),
    Rect.fromLTWH(3 / 5, 0, 2 / 5, 1 / 5),
    Rect.fromLTWH(3 / 5, 1 / 5, 2 / 5, 1 / 5),
    Rect.fromLTWH(3 / 5, 2 / 5, 2 / 5, 1 / 5),
    Rect.fromLTWH(0, 3 / 5, 1 / 5, 2 / 5),
    Rect.fromLTWH(1 / 5, 3 / 5, 1 / 5, 2 / 5),
    Rect.fromLTWH(2 / 5, 3 / 5, 1 / 5, 2 / 5),
    Rect.fromLTWH(3 / 5, 3 / 5, 1 / 5, 2 / 5),
    Rect.fromLTWH(4 / 5, 3 / 5, 1 / 5, 2 / 5),
  ];

  static const _dualFocusSix = [
    Rect.fromLTWH(0, 0, 1 / 2, 1 / 2),
    Rect.fromLTWH(1 / 2, 0, 1 / 2, 1 / 2),
    Rect.fromLTWH(0, 1 / 2, 1 / 3, 1 / 4),
    Rect.fromLTWH(1 / 3, 1 / 2, 1 / 3, 1 / 4),
    Rect.fromLTWH(2 / 3, 1 / 2, 1 / 3, 1 / 4),
    Rect.fromLTWH(0, 3 / 4, 1 / 3, 1 / 4),
    Rect.fromLTWH(1 / 3, 3 / 4, 1 / 3, 1 / 4),
    Rect.fromLTWH(2 / 3, 3 / 4, 1 / 3, 1 / 4),
  ];

  static const _dualFocusEight = [
    Rect.fromLTWH(0, 0, 1 / 2, 1 / 2),
    Rect.fromLTWH(1 / 2, 0, 1 / 2, 1 / 2),
    Rect.fromLTWH(0, 1 / 2, 1 / 4, 1 / 4),
    Rect.fromLTWH(1 / 4, 1 / 2, 1 / 4, 1 / 4),
    Rect.fromLTWH(2 / 4, 1 / 2, 1 / 4, 1 / 4),
    Rect.fromLTWH(3 / 4, 1 / 2, 1 / 4, 1 / 4),
    Rect.fromLTWH(0, 3 / 4, 1 / 4, 1 / 4),
    Rect.fromLTWH(1 / 4, 3 / 4, 1 / 4, 1 / 4),
    Rect.fromLTWH(2 / 4, 3 / 4, 1 / 4, 1 / 4),
    Rect.fromLTWH(3 / 4, 3 / 4, 1 / 4, 1 / 4),
  ];

  static const _centerFocusTwelve = [
    Rect.fromLTWH(1 / 3, 1 / 3, 1 / 3, 1 / 3),
    Rect.fromLTWH(0, 0, 1 / 4, 1 / 3),
    Rect.fromLTWH(1 / 4, 0, 1 / 4, 1 / 3),
    Rect.fromLTWH(2 / 4, 0, 1 / 4, 1 / 3),
    Rect.fromLTWH(3 / 4, 0, 1 / 4, 1 / 3),
    Rect.fromLTWH(0, 2 / 3, 1 / 4, 1 / 3),
    Rect.fromLTWH(1 / 4, 2 / 3, 1 / 4, 1 / 3),
    Rect.fromLTWH(2 / 4, 2 / 3, 1 / 4, 1 / 3),
    Rect.fromLTWH(3 / 4, 2 / 3, 1 / 4, 1 / 3),
    Rect.fromLTWH(0, 1 / 3, 1 / 6, 1 / 3),
    Rect.fromLTWH(1 / 6, 1 / 3, 1 / 6, 1 / 3),
    Rect.fromLTWH(5 / 6, 1 / 3, 1 / 6, 1 / 3),
    Rect.fromLTWH(4 / 6, 1 / 3, 1 / 6, 1 / 3),
  ];

  static const _tripleFocusNine = [
    Rect.fromLTWH(0, 0, 1 / 3, 2 / 3),
    Rect.fromLTWH(1 / 3, 0, 1 / 3, 2 / 3),
    Rect.fromLTWH(2 / 3, 0, 1 / 3, 2 / 3),
    Rect.fromLTWH(0, 2 / 3, 1 / 3, 1 / 9),
    Rect.fromLTWH(1 / 3, 2 / 3, 1 / 3, 1 / 9),
    Rect.fromLTWH(2 / 3, 2 / 3, 1 / 3, 1 / 9),
    Rect.fromLTWH(0, 7 / 9, 1 / 3, 1 / 9),
    Rect.fromLTWH(1 / 3, 7 / 9, 1 / 3, 1 / 9),
    Rect.fromLTWH(2 / 3, 7 / 9, 1 / 3, 1 / 9),
    Rect.fromLTWH(0, 8 / 9, 1 / 3, 1 / 9),
    Rect.fromLTWH(1 / 3, 8 / 9, 1 / 3, 1 / 9),
    Rect.fromLTWH(2 / 3, 8 / 9, 1 / 3, 1 / 9),
  ];
}
