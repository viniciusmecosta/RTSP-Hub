import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rtsp_hub/features/camera_catalog/presentation/camera_setup_wizard.dart';

void main() {
  for (final width in [320.0, 1100.0]) {
    testWidgets('wizard validates and saves through three steps at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final form = GlobalKey<FormState>();
      final name = TextEditingController();
      final host = TextEditingController();
      final user = TextEditingController();
      final password = TextEditingController();
      addTearDown(() {
        name.dispose();
        host.dispose();
        user.dispose();
        password.dispose();
      });
      var saves = 0;
      var tests = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Form(
                key: form,
                child: CameraSetupWizard(
                  name: name,
                  host: host,
                  username: user,
                  password: password,
                  validate: () => form.currentState!.validate(),
                  onTest: () => tests++,
                  onSave: () => saves++,
                  onAdvanced: () {},
                  onTemplate: (_) {},
                  busy: false,
                  tested: false,
                  editing: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Continuar'));
      await tester.pump();
      expect(find.text('Informe o endereço da câmera.'), findsOneWidget);
      host.text = '192.168.1.10';
      await tester.tap(find.text('Continuar'));
      await tester.pump();
      expect(find.text('Senha'), findsOneWidget);
      expect(find.textContaining('RTSP'), findsNothing);
      await tester.tap(find.text('Continuar'));
      await tester.pump();
      await tester.tap(find.text('Testar conexão'));
      await tester.tap(find.text('Salvar e conectar depois'));
      expect(tests, 1);
      expect(saves, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
