import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rtsp_hub/shared/platform/linux_startup_service.dart';

void main() {
  test('creates and removes the per-user Linux autostart entry', () async {
    final directory = await Directory.systemTemp.createTemp('rtsp-startup-');
    addTearDown(() => directory.delete(recursive: true));
    final service = LinuxStartupService(
      configHome: directory.path,
      executable: '/opt/RTSP Hub/rtsp_hub',
    );

    expect(await service.isEnabled(), isFalse);
    expect(await service.setEnabled(true), isTrue);

    final entry = File('${directory.path}/autostart/rtsp-hub.desktop');
    expect(await entry.exists(), isTrue);
    expect(
      await entry.readAsString(),
      contains('Exec="/opt/RTSP Hub/rtsp_hub"'),
    );
    expect(await service.isEnabled(), isTrue);
    expect(await service.setEnabled(false), isTrue);
    expect(await service.isEnabled(), isFalse);
  });
}
