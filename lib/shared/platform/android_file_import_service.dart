import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class IncomingBackupFile {
  const IncomingBackupFile({required this.name, required this.content});

  final String name;
  final String content;
}

class AndroidFileImportService {
  AndroidFileImportService({MethodChannel? channel})
    : _channel =
          channel ?? const MethodChannel('com.rtsp.rtsp_hub/file_import');

  final MethodChannel _channel;
  StreamController<IncomingBackupFile>? _controller;

  Future<IncomingBackupFile?> getInitialFile() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'getInitialFile',
      );
      if (result != null) {
        final name = result['name'] as String? ?? 'backup.json';
        final content = result['content'] as String? ?? '';
        if (content.isNotEmpty) {
          return IncomingBackupFile(name: name, content: content);
        }
      }
    } on Object {
      // Falha ou plataforma sem canal nativo
    }
    return null;
  }

  Stream<IncomingBackupFile> get fileStream {
    _controller ??= StreamController<IncomingBackupFile>.broadcast(
      onListen: _startListening,
    );
    return _controller!.stream;
  }

  void _startListening() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onFileReceived') {
        final args = call.arguments;
        if (args is Map) {
          final name = args['name'] as String? ?? 'backup.json';
          final content = args['content'] as String? ?? '';
          if (content.isNotEmpty) {
            _controller?.add(IncomingBackupFile(name: name, content: content));
          }
        }
      }
    });
  }

  void dispose() {
    _controller?.close();
    _controller = null;
  }
}
