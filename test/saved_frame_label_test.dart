import 'package:flutter_test/flutter_test.dart';
import 'package:rtsp_hub/features/camera_catalog/domain/camera_device.dart';
import 'package:rtsp_hub/features/camera_catalog/presentation/saved_frame_label.dart';

void main() {
  test('legacy images never receive an invented capture date', () {
    expect(savedFrameLabel(null), 'Imagem salva · data não registrada');
  });

  test('the capture date is explicit and survives serialization', () {
    final date = DateTime(2026, 10, 12, 9, 5);
    final camera = CameraDevice(
      id: 'a',
      name: 'Entrada',
      host: '10.0.0.2',
      mainPath: '/main',
      thumbnailCapturedAt: date,
    );
    final restored = CameraDevice.fromJson(camera.toJson());
    expect(restored.thumbnailCapturedAt, date.toUtc());
    expect(
      savedFrameLabel(restored.thumbnailCapturedAt),
      'Imagem salva · 12/10/2026 09:05',
    );
  });
}
