import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rtsp_hub/features/layouts/domain/layout_preset.dart';
import 'package:rtsp_hub/features/monitor/presentation/widgets/monitor_camera_viewport.dart';

void main() {
  for (final reduced in [false, true]) {
    testWidgets(
      'focus animates without remounting the camera (reduced: $reduced)',
      (tester) async {
        int? focused;
        late StateSetter update;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: reduced),
              child: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return MonitorCameraViewport(
                    layout: LayoutPreset.byId('GRID_4'),
                    pageStart: 0,
                    focusedIndex: focused,
                    children: [
                      for (var i = 0; i < 4; i++)
                        ColoredBox(
                          key: ValueKey('tile-$i'),
                          color: Colors.blue,
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final tile = find.byKey(const ValueKey('tile-0'));
        final element = tester.element(tile);
        final initial = tester.getSize(tile);
        update(() => focused = 0);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 110));
        final during = tester.getSize(tile);
        expect(during.width, greaterThan(initial.width));
        if (reduced) {
          expect(during, tester.getSize(find.byType(MonitorCameraViewport)));
        } else {
          expect(
            during.width,
            lessThan(tester.getSize(find.byType(MonitorCameraViewport)).width),
          );
        }
        await tester.pumpAndSettle();
        expect(
          tester.getSize(tile),
          tester.getSize(find.byType(MonitorCameraViewport)),
        );
        expect(tester.element(tile), same(element));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'a scrolled grid returns to the same position without remounting tiles',
    (tester) async {
      tester.view.physicalSize = const Size(360, 300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      int? focused;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return MonitorCameraViewport(
                layout: LayoutPreset.byId('GRID_16'),
                pageStart: 0,
                focusedIndex: focused,
                children: [
                  for (var i = 0; i < 16; i++)
                    ColoredBox(key: ValueKey('tile-$i'), color: Colors.blue),
                ],
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final elements = [
        for (var i = 0; i < 16; i++)
          tester.element(find.byKey(ValueKey('tile-$i'))),
      ];
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -240),
      );
      await tester.pumpAndSettle();
      final scroll = tester
          .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
          .controller!;
      final previousOffset = scroll.offset;
      expect(previousOffset, greaterThan(0));
      update(() => focused = 12);
      await tester.pumpAndSettle();
      expect(scroll.offset, 0);
      expect(
        tester.getRect(find.byKey(const ValueKey('tile-12'))),
        const Rect.fromLTWH(0, 0, 360, 300),
      );
      update(() => focused = null);
      await tester.pumpAndSettle();
      expect(scroll.offset, closeTo(previousOffset, 0.01));
      for (var i = 0; i < 16; i++) {
        expect(
          tester.element(find.byKey(ValueKey('tile-$i'))),
          same(elements[i]),
        );
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'rotation keeps the focused surface mounted and fits the new viewport',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: MonitorCameraViewport(
            layout: LayoutPreset.byId('GRID_4'),
            pageStart: 0,
            focusedIndex: 2,
            children: [
              for (var i = 0; i < 4; i++)
                ColoredBox(key: ValueKey('tile-$i'), color: Colors.blue),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      final element = tester.element(find.byKey(const ValueKey('tile-2')));
      tester.view.physicalSize = const Size(640, 360);
      await tester.pumpAndSettle();
      expect(
        tester.element(find.byKey(const ValueKey('tile-2'))),
        same(element),
      );
      expect(
        tester.getRect(find.byKey(const ValueKey('tile-2'))),
        const Rect.fromLTWH(0, 0, 640, 360),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
