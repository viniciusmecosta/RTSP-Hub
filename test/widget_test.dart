import 'package:flutter_test/flutter_test.dart';
import 'package:rtsp_view/main.dart';

void main() {
  testWidgets('abre a tela inicial do RTSP View', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.text('Visão geral'), findsOneWidget);
    expect(find.text('Adicionar câmera'), findsOneWidget);
  });
}
