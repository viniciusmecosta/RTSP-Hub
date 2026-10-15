import 'dart:io';

import 'package:rtsp_hub/shared/infrastructure/single_instance/single_instance_guard.dart';

Future<void> main(List<String> arguments) async {
  final guard = await SingleInstanceGuard.acquire(
    baseDirectory: Directory(arguments.single),
  );
  if (guard == null) {
    stdout.writeln('locked-elsewhere');
    exitCode = 1;
    return;
  }
  stdout.writeln('locked');
  await stdout.flush();
  await stdin.first;
  await guard.release();
}
