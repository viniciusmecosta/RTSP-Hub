import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rtsp_hub/app/state/app_store.dart';
import 'package:rtsp_hub/features/camera_catalog/domain/camera_channel.dart';
import 'package:rtsp_hub/features/camera_catalog/domain/camera_device.dart';
import 'package:rtsp_hub/features/camera_catalog/presentation/camera_editor_dialog.dart';

import 'global_connection_backup_test.dart'
    show MemoryRepository, MemoryCredentials;

void main() {
  testWidgets(
    'editor loads the selected channel endpoints instead of the first channel',
    (tester) async {
      const camera = CameraDevice(
        id: 'a',
        name: 'Gravador',
        host: '10.0.0.2',
        mainPath: '/main1',
        subPath: '/sub1',
        selectedChannelId: '3',
        channels: [
          CameraChannel(
            id: '1',
            label: 'Canal 1',
            main: CameraStream(path: '/main1'),
            sub: CameraStream(path: '/sub1'),
          ),
          CameraChannel(
            id: '3',
            label: 'Canal 3',
            main: CameraStream(path: '/main3', port: 8554),
            sub: CameraStream(path: '/sub3', port: 10554),
          ),
        ],
      );
      final store = AppStore(
        repository: MemoryRepository(),
        credentials: MemoryCredentials(),
      );
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CameraEditorDialog(
              camera: camera,
              password: null,
              globalPassword: null,
              store: store,
            ),
          ),
        ),
      );
      final main = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Canal / caminho específico'),
      );
      final sub = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Subfluxo específico (opcional)'),
      );
      final port = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Porta'),
      );
      expect(main.controller!.text, '/main3');
      expect(sub.controller!.text, '/sub3');
      expect(port.controller!.text, '8554');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
