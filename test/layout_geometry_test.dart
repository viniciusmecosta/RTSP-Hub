import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:rtsp_hub/features/layouts/domain/layout_geometry.dart';
import 'package:rtsp_hub/features/layouts/domain/layout_preset.dart';

void main() {
  test('grade dinâmica acomoda mais de dezesseis câmeras', () {
    final layout = LayoutPreset.byId('GRID_ALL', cameraCount: 17);

    expect(layout.cameraCount, 17);
    expect(layout.columns * layout.rows, greaterThanOrEqualTo(17));
  });

  group('LayoutGeometry', () {
    final focusedLayouts = LayoutPreset.all.where(
      (layout) => layout.focusIndex != null,
    );

    for (final layout in focusedLayouts) {
      test(
        '${layout.name} covers the canvas with the expected number of tiles',
        () {
          final tiles = LayoutGeometry.tiles(layout.id, const Size(1000, 800));

          expect(tiles, hasLength(layout.cameraCount));
          expect(
            tiles.fold<double>(
                  0,
                  (area, rect) => area + rect.width * rect.height,
                ) /
                (1000 * 800),
            closeTo(1, 0.000001),
          );
          for (final tile in tiles) {
            expect(tile.left, greaterThanOrEqualTo(0));
            expect(tile.top, greaterThanOrEqualTo(0));
            expect(tile.right, lessThanOrEqualTo(1000));
            expect(tile.bottom, lessThanOrEqualTo(800));
            expect(tile.isEmpty, isFalse);
          }
          for (var first = 0; first < tiles.length; first++) {
            for (var second = first + 1; second < tiles.length; second++) {
              final intersection = tiles[first].intersect(tiles[second]);
              expect(
                intersection.width <= 0.000001 ||
                    intersection.height <= 0.000001,
                isTrue,
                reason:
                    '$first overlaps $second: ${tiles[first]} ${tiles[second]}',
              );
            }
          }
        },
      );
    }

    test('unknown layout has no custom geometry', () {
      expect(LayoutGeometry.tiles('missing', const Size(100, 100)), isEmpty);
    });
  });
}
