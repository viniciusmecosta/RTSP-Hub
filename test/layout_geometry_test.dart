import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:rtsp_hub/features/layouts/domain/freeform_slot.dart';
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

    test('fittedVideoSize respeita contain, fill e smart sem exagerar', () {
      const ultraWideCell = Size(1200, 300); // 4:1 aspect ratio
      final contain = LayoutGeometry.fittedVideoSize(
        ultraWideCell,
        fitMode: 'contain',
      );
      expect(contain.height, 300);
      expect(contain.width, closeTo(300 * (16 / 9), 0.01));

      final fill = LayoutGeometry.fittedVideoSize(
        ultraWideCell,
        fitMode: 'fill',
      );
      expect(fill, ultraWideCell);

      final smart = LayoutGeometry.fittedVideoSize(
        ultraWideCell,
        fitMode: 'smart',
      );
      expect(smart.height, 300);
      expect(smart.width, greaterThan(contain.width));
      expect(
        smart.width,
        closeTo(contain.width * LayoutGeometry.maxAspectStretch, 0.01),
      );
      expect(smart.width, lessThan(ultraWideCell.width));
    });

    test(
      'bestColumns escolhe colunas melhores para a proporção das câmeras',
      () {
        final gridAll6 = LayoutPreset.byId('GRID_ALL', cameraCount: 6);
        final portraitCols = LayoutGeometry.bestColumns(
          layout: gridAll6,
          canvas: const Size(400, 800),
          visibleCount: 6,
        );
        final landscapeCols = LayoutGeometry.bestColumns(
          layout: gridAll6,
          canvas: const Size(1920, 1080),
          visibleCount: 6,
        );
        expect(portraitCols, lessThanOrEqualTo(2));
        expect(landscapeCols, 3);
      },
    );

    test(
      'freeformTiles e autoArrangeFreeform calculam espaços personalizados',
      () {
        final slots = [
          const FreeformSlot(
            cameraId: 'c1',
            x: 0,
            y: 0,
            width: 0.5,
            height: 1.0,
          ),
          const FreeformSlot(
            cameraId: 'c2',
            x: 0.5,
            y: 0,
            width: 0.5,
            height: 1.0,
          ),
        ];
        final tiles = LayoutGeometry.freeformTiles(
          slots,
          const Size(1000, 500),
        );
        expect(tiles.length, 2);
        expect(tiles[0].left, 0);
        expect(tiles[0].width, 500);
        expect(tiles[0].height, 500);
        expect(tiles[1].left, 500);
        expect(tiles[1].width, 500);

        final arranged = LayoutGeometry.autoArrangeFreeform([
          const FreeformSlot(cameraId: 'c1'),
          const FreeformSlot(cameraId: 'c2'),
          const FreeformSlot(cameraId: 'c3'),
        ]);
        expect(arranged.length, 3);
        expect(arranged[0].width, closeTo(0.67, 0.01));
        expect(arranged[1].x, closeTo(0.67, 0.01));
        expect(arranged[2].x, closeTo(0.67, 0.01));
      },
    );
  });
}
