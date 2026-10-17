import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rtsp_hub/features/camera_catalog/presentation/widgets/global_field_hint.dart';

void main() {
  testWidgets('inheritance updates as a field is filled and cleared', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GlobalFieldHint(controller: controller, globalValue: 'admin'),
        ),
      ),
    );
    expect(find.text('Usando global: admin'), findsOneWidget);
    controller.text = 'operator';
    await tester.pump();
    expect(find.text('Valor específico desta câmera'), findsOneWidget);
    controller.clear();
    await tester.pump();
    expect(find.text('Usando global: admin'), findsOneWidget);
  });

  testWidgets('a password made of spaces is an explicit credential', (
    tester,
  ) async {
    final controller = TextEditingController(text: ' ');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GlobalFieldHint(
            controller: controller,
            globalValue: 'senha configurada no cofre',
            trim: false,
          ),
        ),
      ),
    );
    expect(find.text('Valor específico desta câmera'), findsOneWidget);
    expect(find.textContaining('Usando global'), findsNothing);
  });
}
