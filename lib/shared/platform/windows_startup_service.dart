import 'dart:io';

import 'package:flutter/foundation.dart';

class WindowsStartupService {
  static const _registryPath =
      r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';
  static const _valueName = 'RTSP Hub';
  static const _legacyValueName = 'RTSP View';

  bool get supported => !kIsWeb && Platform.isWindows;

  Future<bool> isEnabled() async {
    if (!supported) return false;
    try {
      if (await _contains(_valueName)) {
        await _deleteIfExists(_legacyValueName);
        return true;
      }
      if (!await _contains(_legacyValueName)) return false;
      return setEnabled(true);
    } on Object {
      return false;
    }
  }

  Future<bool> setEnabled(bool enabled) async {
    if (!supported) return false;
    try {
      if (!enabled) {
        final current = await _deleteIfExists(_valueName);
        final legacy = await _deleteIfExists(_legacyValueName);
        return current && legacy;
      }
      final result = await Process.run('reg.exe', [
        'add',
        _registryPath,
        '/v',
        _valueName,
        '/t',
        'REG_SZ',
        '/d',
        '"${Platform.resolvedExecutable}"',
        '/f',
      ]);
      if (result.exitCode != 0) return false;
      return _deleteIfExists(_legacyValueName);
    } on Object {
      return false;
    }
  }

  Future<bool> _contains(String value) async {
    final result = await Process.run('reg.exe', [
      'query',
      _registryPath,
      '/v',
      value,
    ]);
    return result.exitCode == 0;
  }

  Future<bool> _deleteIfExists(String value) async {
    if (!await _contains(value)) return true;
    final result = await Process.run('reg.exe', [
      'delete',
      _registryPath,
      '/v',
      value,
      '/f',
    ]);
    return result.exitCode == 0;
  }
}
