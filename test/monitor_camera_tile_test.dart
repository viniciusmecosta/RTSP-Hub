import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rtsp_hub/features/camera_catalog/domain/camera_device.dart';
import 'package:rtsp_hub/features/monitor/application/rtsp_session.dart';
import 'package:rtsp_hub/features/monitor/presentation/widgets/monitor_camera_tile.dart';

void main() {
  testWidgets(
    'a camera sem controller mostra a reconexao mesmo apos um quadro anterior',
    (tester) async {
      const camera = CameraDevice(
        id: 'front',
        name: 'Entrada principal e acesso lateral da garagem',
        host: '192.168.1.10',
        mainPath: '/main',
      );
      final session = RtspSession(
        camera: camera,
        password: null,
        defaultPort: 554,
        bufferMs: 300,
        useMainStream: false,
      );
      addTearDown(session.disposeSession);
      session.firstFrameRendered.value = true;
      session.status.value = CameraPlaybackStatus.reconnecting;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 160,
                height: 110,
                child: MonitorCameraTile(
                  camera: camera,
                  session: session,
                  onTap: _noop,
                  onFocus: _noop,
                  onRetry: null,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Reconectando à câmera'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('monitor identifies the channel selected for a camera', (
    tester,
  ) async {
    const camera = CameraDevice(
      id: 'front',
      name: 'Entrada',
      host: '192.168.1.10',
      mainPath: '/main',
      savedPaths: ['/main', '/channel-2'],
      selectedPath: '/channel-2',
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 480,
            height: 270,
            child: MonitorCameraTile(
              camera: camera,
              session: null,
              onTap: _noop,
              onFocus: _noop,
              onRetry: null,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Entrada (/channel-2)'), findsOneWidget);
    expect(find.text('Entrada (/main)'), findsNothing);
  });
}

void _noop() {}
