import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rtsp_hub/features/camera_catalog/domain/camera_device.dart';
import 'package:rtsp_hub/features/camera_catalog/presentation/camera_preview_dialog.dart';
import 'package:rtsp_hub/features/monitor/application/rtsp_session.dart';

const camera = CameraDevice(
  id: 'camera',
  name: 'Portaria',
  host: '192.168.1.2',
  mainPath: '/live',
);

class PreviewSession extends RtspSession {
  PreviewSession()
    : super(
        camera: camera,
        password: null,
        defaultPort: 554,
        bufferMs: 250,
        useMainStream: true,
      );
  bool closed = false;
  int starts = 0;

  @override
  Future<void> start() async {
    starts++;
    status.value = CameraPlaybackStatus.connecting;
  }

  @override
  Future<void> disposeSession() async {
    closed = true;
    await super.disposeSession();
  }
}

void main() {
  for (final size in [
    const Size(360, 640),
    const Size(640, 360),
    const Size(1024, 768),
  ]) {
    testWidgets('preview reports failure and closes its session at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final session = PreviewSession();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => CameraPreviewDialog(
                    camera: camera,
                    password: null,
                    defaultPort: 554,
                    bufferMs: 250,
                    session: session,
                  ),
                ),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Conectando à câmera'), findsOneWidget);
      session.error.value = 'Confira a rede e os dados da câmera';
      session.status.value = CameraPlaybackStatus.error;
      await tester.pumpAndSettle();
      expect(find.text('Tentar novamente'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Tentar novamente'));
      await tester.tap(find.text('Tentar novamente'));
      await tester.pump();
      expect(session.starts, 2);
      await tester.ensureVisible(find.byTooltip('Fechar vídeo'));
      await tester.tap(find.byTooltip('Fechar vídeo'));
      await tester.pumpAndSettle();
      expect(session.closed, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}
