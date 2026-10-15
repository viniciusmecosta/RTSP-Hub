import 'dart:io';

import 'package:flutter/foundation.dart';

class WindowsStartupService {
  static const _registryPath =
      r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';
  static const _valueName = 'RTSP Hub';

  bool get supported => !kIsWeb && Platform.isWindows;

  Future<bool> isEnabled() async {
    if (!supported) return false;
    try {
      final result = await Process.run('reg.exe', [
        'query',
        _registryPath,
        '/v',
        _valueName,
      ]);
      return result.exitCode == 0;
    } on Object {
      return false;
    }
  }

  Future<bool> setEnabled(bool enabled) async {
    if (!supported) return false;
    try {
      final result = enabled
          ? await Process.run('reg.exe', [
              'add',
              _registryPath,
              '/v',
              _valueName,
              '/t',
              'REG_SZ',
              '/d',
              '"${Platform.resolvedExecutable}"',
              '/f',
            ])
          : await Process.run('reg.exe', [
              'delete',
              _registryPath,
              '/v',
              _valueName,
              '/f',
            ]);
      return result.exitCode == 0;
    } on Object {
      return false;
    }
  }
}
