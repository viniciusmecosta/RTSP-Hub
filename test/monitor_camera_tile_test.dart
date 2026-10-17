import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rtsp_hub/shared/design_system/app_theme.dart';
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
  for (final theme in [AppTheme.light, AppTheme.dark]) {
    testWidgets('channel menu uses theme contrast in ${theme.brightness}', (
      tester,
    ) async {
      const camera = CameraDevice(
        id: 'a',
        name: 'Entrada',
        host: '10.0.0.2',
        mainPath: '/main',
        savedPaths: ['/main', '/other'],
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(
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
      await tester.tap(find.byTooltip('Opções da câmera'));
      await tester.pumpAndSettle();
      final icon = tester.widget<Icon>(
        find.byIcon(Icons.radio_button_unchecked),
      );
      expect(icon.color, theme.colorScheme.onSurfaceVariant);
      final foreground = icon.color!.computeLuminance();
      final background = theme.colorScheme.surfaceContainer.computeLuminance();
      final lighter = foreground > background ? foreground : background;
      final darker = foreground > background ? background : foreground;
      expect((lighter + 0.05) / (darker + 0.05), greaterThanOrEqualTo(3));
      expect(tester.takeException(), isNull);
    });
  }
}

void _noop() {}
