import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rtsp_hub/features/monitor/application/rtsp_session.dart';
import 'package:rtsp_hub/features/monitor/presentation/camera_loading_view.dart';

void main() {
  Widget app({
    required CameraPlaybackStatus status,
    String? error,
    Duration? retryDelay,
    VoidCallback? onRetry,
    Size size = const Size(180, 110),
  }) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: CameraLoadingView(
            status: status,
            error: error,
            retryDelay: retryDelay,
            onRetry: onRetry,
          ),
        ),
      ),
    ),
  );

  testWidgets('mostra carregamento compacto sem estouro', (tester) async {
    await tester.pumpWidget(app(status: CameraPlaybackStatus.connecting));

    expect(find.text('Conectando à câmera'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('explica reconexão e prazo sem esconder o erro', (tester) async {
    await tester.pumpWidget(
      app(
        status: CameraPlaybackStatus.reconnecting,
        error: 'A câmera não respondeu.',
        retryDelay: const Duration(seconds: 4),
        size: const Size(300, 180),
      ),
    );

    expect(find.text('Reconectando à câmera'), findsOneWidget);
    expect(find.textContaining('Nova tentativa em 4 s'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('permite tentar novamente em câmera pequena', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      app(
        status: CameraPlaybackStatus.error,
        error: 'Credenciais inválidas.',
        onRetry: () => retried = true,
        size: const Size(140, 75),
      ),
    );

    await tester.tap(find.byIcon(Icons.refresh));
    expect(retried, isTrue);
    expect(tester.takeException(), isNull);
  });
}
