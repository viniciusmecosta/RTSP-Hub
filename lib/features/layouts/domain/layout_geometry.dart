import 'dart:ui';

class LayoutGeometry {
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
