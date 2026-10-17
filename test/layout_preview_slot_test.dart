import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rtsp_hub/features/layouts/presentation/widgets/layout_preview_slot.dart';

void main() {
  testWidgets('supports touch selection and accessible move menu', (
    tester,
  ) async {
    int? target;
    var selected = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 220,
            height: 140,
            child: LayoutPreviewSlot(
              index: 0,
              count: 4,
              onSelect: () => selected = true,
              onSwap: (index) => target = index,
              child: const ColoredBox(color: Colors.blue),
            ),
          ),
        ),
      ),
    );
    await tester.tapAt(const Offset(40, 40));
    expect(selected, isTrue);
    await tester.tap(find.byTooltip('Mover posição 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trocar com posição 3'));
    await tester.pumpAndSettle();
    expect(target, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('supports dragging from one preview position to another', (
    tester,
  ) async {
    int? movedFrom;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              SizedBox(
                width: 180,
                height: 120,
                child: LayoutPreviewSlot(
                  index: 0,
                  count: 2,
                  onSelect: () {},
                  onSwap: (_) {},
                  child: const ColoredBox(color: Colors.blue),
                ),
              ),
              SizedBox(
                width: 180,
                height: 120,
                child: LayoutPreviewSlot(
                  index: 1,
                  count: 2,
                  onSelect: () {},
                  onSwap: (index) => movedFrom = index,
                  child: const ColoredBox(color: Colors.black),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final first = find.byKey(const ValueKey('layout-preview-slot-0'));
    final second = find.byKey(const ValueKey('layout-preview-slot-1'));
    final gesture = await tester.startGesture(tester.getCenter(first));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(tester.getCenter(second));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(movedFrom, 0);
    expect(tester.takeException(), isNull);
  });
}
