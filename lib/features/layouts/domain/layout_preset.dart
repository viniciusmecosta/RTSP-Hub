import 'dart:math';

class LayoutPreset {
  const LayoutPreset({
    required this.id,
    required this.name,
    required this.rows,
    required this.columns,
    required this.cameraCount,
    this.focusIndex,
  });

  final String id;
  final String name;
  final int rows;
  final int columns;
  final int cameraCount;
  final int? focusIndex;

  static const all = <LayoutPreset>[
    LayoutPreset(
      id: 'GRID_ALL',
      name: 'Todas as câmeras',
      rows: 1,
      columns: 1,
      cameraCount: 1,
    ),
    LayoutPreset(
      id: 'SINGLE',
      name: '1 câmera',
      rows: 1,
      columns: 1,
      cameraCount: 1,
    ),
    LayoutPreset(
      id: 'GRID_2H',
      name: '2 lado a lado',
      rows: 1,
      columns: 2,
      cameraCount: 2,
    ),
    LayoutPreset(
      id: 'GRID_2V',
      name: '2 empilhadas',
      rows: 2,
      columns: 1,
      cameraCount: 2,
    ),
    LayoutPreset(
      id: 'GRID_4',
      name: 'Grade 2 × 2',
      rows: 2,
      columns: 2,
      cameraCount: 4,
    ),
    LayoutPreset(
      id: 'GRID_6',
      name: 'Grade 2 × 3',
      rows: 2,
      columns: 3,
      cameraCount: 6,
    ),
    LayoutPreset(
      id: 'GRID_8',
      name: 'Grade 2 × 4',
      rows: 2,
      columns: 4,
      cameraCount: 8,
    ),
    LayoutPreset(
      id: 'GRID_9',
      name: 'Grade 3 × 3',
      rows: 3,
      columns: 3,
      cameraCount: 9,
    ),
    LayoutPreset(
      id: 'GRID_12',
      name: 'Grade 3 × 4',
      rows: 3,
      columns: 4,
      cameraCount: 12,
    ),
    LayoutPreset(
      id: 'GRID_16',
      name: 'Grade 4 × 4',
      rows: 4,
      columns: 4,
      cameraCount: 16,
    ),
    LayoutPreset(
      id: 'FOCUS_RIGHT_3',
      name: 'Foco à esquerda · 3 câmeras',
      rows: 3,
      columns: 4,
      cameraCount: 4,
      focusIndex: 0,
    ),
    LayoutPreset(
      id: 'FOCUS_LEFT_3',
      name: 'Foco à direita · 3 câmeras',
      rows: 3,
      columns: 4,
      cameraCount: 4,
      focusIndex: 0,
    ),
    LayoutPreset(
      id: 'FOCUS_BASE_RIGHT_5',
      name: 'Foco · base e direita',
      rows: 3,
      columns: 3,
      cameraCount: 6,
      focusIndex: 0,
    ),
    LayoutPreset(
      id: 'FOCUS_LEFT_7',
      name: 'Foco · 7 laterais',
      rows: 4,
      columns: 4,
      cameraCount: 8,
      focusIndex: 0,
    ),
    LayoutPreset(
      id: 'FOCUS_BASE_RIGHT_8',
      name: 'Foco · 8 laterais',
      rows: 4,
      columns: 4,
      cameraCount: 9,
      focusIndex: 0,
    ),
    LayoutPreset(
      id: 'DUAL_FOCUS_6',
      name: '2 focos · 6 câmeras',
      rows: 4,
      columns: 4,
      cameraCount: 8,
      focusIndex: 0,
    ),
    LayoutPreset(
      id: 'DUAL_FOCUS_8',
      name: '2 focos · 8 câmeras',
      rows: 4,
      columns: 4,
      cameraCount: 10,
      focusIndex: 0,
    ),
    LayoutPreset(
      id: 'CENTER_FOCUS_12',
      name: 'Foco central · 12 câmeras',
      rows: 5,
      columns: 5,
      cameraCount: 13,
      focusIndex: 0,
    ),
    LayoutPreset(
      id: 'TRIPLE_FOCUS_9',
      name: '3 focos · 9 câmeras',
      rows: 4,
      columns: 6,
      cameraCount: 12,
      focusIndex: 0,
    ),
  ];

  static LayoutPreset byId(String id, {int cameraCount = 1}) {
    if (id == 'GRID_ALL') {
      final count = max(1, cameraCount);
      final columns = sqrt(count).ceil();
      return LayoutPreset(
        id: 'GRID_ALL',
        name: 'Todas as câmeras',
        rows: (count + columns - 1) ~/ columns,
        columns: columns,
        cameraCount: count,
      );
    }
    return all.firstWhere((preset) => preset.id == id, orElse: () => all[4]);
  }
}
