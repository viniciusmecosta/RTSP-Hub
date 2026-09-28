import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rtsp_view/shared/infrastructure/single_instance/single_instance_guard.dart';

void main() {
  test('blocks another process and releases lock after shutdown', () async {
    final directory = await Directory.systemTemp.createTemp('rtsp-view-lock');
    final process = await Process.start('dart', [
      '--packages=${Directory.current.path}/.dart_tool/package_config.json',
      '${Directory.current.path}/tool/hold_single_instance.dart',
      directory.path,
    ], workingDirectory: Directory.current.path);
    final ready = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .firstWhere((line) => line == 'locked');
    expect(await ready.timeout(const Duration(seconds: 10)), 'locked');
    expect(await SingleInstanceGuard.acquire(baseDirectory: directory), isNull);

    process.stdin.writeln('shutdown');
    await process.stdin.flush();
    await process.stdin.close();
    expect(await process.exitCode.timeout(const Duration(seconds: 10)), 0);
    final next = await SingleInstanceGuard.acquire(baseDirectory: directory);

    expect(next, isNotNull);
    await next!.release();
    await directory.delete(recursive: true);
  });
}
