import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:rtsp_view/main.dart';

void main() {
  testWidgets('abre a tela inicial do RTSP View', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Adicionar câmera'), findsOneWidget);
  });

  testWidgets('atalho F3 abre diagnósticos e F2 volta para câmeras', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Monitor'));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.f3);
    await tester.pumpAndSettle();
    expect(find.text('Diagnósticos da sessão'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.f2);
    await tester.pumpAndSettle();
    expect(find.text('Adicionar câmera'), findsWidgets);
  });
}
