import 'package:flutter_test/flutter_test.dart';
import 'package:rtsp_hub/features/camera_catalog/domain/camera_channel.dart';
import 'package:rtsp_hub/features/camera_catalog/domain/camera_device.dart';

void main() {
  test('legacy principal and sub paths remain one channel', () {
    const camera = CameraDevice(
      id: 'a',
      name: 'Entrada',
      host: '10.0.0.2',
      mainPath: '/Streaming/Channels/101',
      subPath: '/Streaming/Channels/102',
      savedPaths: [
        '/Streaming/Channels/101',
        '/Streaming/Channels/102',
        '/Streaming/Channels/301',
        '/Streaming/Channels/302',
      ],
      selectedPath: '/Streaming/Channels/302',
    );
    expect(camera.availableChannels, hasLength(2));
    expect(camera.activeChannel!.label, 'Canal 3');
    expect(camera.playbackPath(useMainStream: true), '/Streaming/Channels/301');
    expect(
      camera.playbackPath(useMainStream: false),
      '/Streaming/Channels/302',
    );
  });

  test('unknown saved paths remain usable without inventing sub paths', () {
    const camera = CameraDevice(
      id: 'a',
      name: 'Entrada',
      host: '10.0.0.2',
      mainPath: '/main',
      subPath: '/sub',
      savedPaths: ['/other'],
      selectedPath: '/other',
    );
    expect(camera.playbackPath(useMainStream: false), '/other');
    expect(camera.playbackPath(useMainStream: true), '/other');
  });

  test(
    'structured channels retain endpoints and independent quality selection',
    () {
      const camera = CameraDevice(
        id: 'a',
        name: 'Entrada',
        host: '10.0.0.2',
        mainPath: '/main',
        selectedChannelId: 'source-3',
        channels: [
          CameraChannel(
            id: 'source-3',
            label: 'Canal 3',
            main: CameraStream(
              path: '/main3',
              port: 8554,
              quality: '1920×1080',
            ),
            sub: CameraStream(path: '/sub3', port: 10554, quality: '640×360'),
          ),
        ],
      );
      final restored = CameraDevice.fromJson(camera.toJson());
      expect(restored.activeChannel!.id, 'source-3');
      expect(restored.playbackStream(useMainStream: true).port, 8554);
      expect(restored.playbackStream(useMainStream: false).port, 10554);
      expect(restored.playbackStream(useMainStream: false).quality, '640×360');
    },
  );

  test('invalid endpoint in imported channels is rejected', () {
    expect(
      () => CameraStream.fromJson({'path': '/main', 'port': 0}),
      throwsFormatException,
    );
    expect(
      () =>
          CameraStream.fromJson({'path': '/main', 'host': 'host with spaces'}),
      throwsFormatException,
    );
  });
}
