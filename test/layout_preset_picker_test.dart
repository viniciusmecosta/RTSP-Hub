import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rtsp_hub/features/layouts/presentation/widgets/layout_preset_picker.dart';

void main() {
  testWidgets('shows visual layouts and selects one on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: LayoutPresetPicker(
              selectedId: 'GRID_4',
              onSelected: (id) => selected = id,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(CustomPaint), findsWidgets);
    await tester.ensureVisible(find.text('2 lado a lado'));
    await tester.tap(find.text('2 lado a lado'));
    expect(selected, 'GRID_2H');
    expect(tester.takeException(), isNull);
  });
}
