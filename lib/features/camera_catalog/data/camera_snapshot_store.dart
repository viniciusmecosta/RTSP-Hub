import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';

class CameraSnapshotStore extends ChangeNotifier {
  CameraSnapshotStore({this.directory});

  static const decodeWidths = [160, 320, 640];

  static int decodeWidth(double pixels) => decodeWidths.firstWhere(
    (width) => width >= pixels,
    orElse: () => decodeWidths.last,
  );

  final Directory? directory;
  Future<Directory>? _resolvedDirectory;
  int revision = 0;

  Future<File> fileFor(String id) async {
    final root = await (_resolvedDirectory ??= _directory());
    final key = sha256.convert(utf8.encode(id));
    final file = File('${root.path}/$key.png');
    if (directory == null &&
        !await file.exists() &&
        !await File('${file.path}.removed').exists()) {
      final support = await getApplicationSupportDirectory();
      final paths = {
        support.path,
        support.path
            .replaceAll('rtsp_hub', 'rtsp_view')
            .replaceAll('rtspHub', 'rtspView')
            .replaceAll('RTSP Hub', 'RTSP View'),
        support.path
            .replaceAll('rtsp_view', 'rtsp_hub')
            .replaceAll('rtspView', 'rtspHub'),
      };
      for (final path in paths) {
        for (final name in ['RTSPHub', 'RTSPView']) {
          final legacy = File('$path/$name/thumbnails/$key.png');
          if (legacy.path == file.path || !await legacy.exists()) continue;
          if (await legacy.length() <= 4 * 1024 * 1024) {
            await legacy.copy(file.path);
          }
          return file;
        }
      }
    }
    return file;
  }

  Future<Directory> _directory() async {
    final root =
        directory ??
        Directory(
          '${(await getApplicationSupportDirectory()).path}/RTSPHub/thumbnails',
        );
    await root.create(recursive: true);
    return root;
  }

  Future<Uint8List?> read(String id) async {
    final file = await fileFor(id);
    if (!await file.exists()) return null;
    if (await file.length() > 4 * 1024 * 1024) {
      throw const FormatException('Miniatura muito grande.');
    }
    return file.readAsBytes();
  }

  Future<bool> save(String id, Uint8List bytes) async {
    if (bytes.isEmpty || bytes.length > 4 * 1024 * 1024) return false;
    try {
      final file = await fileFor(id);
      final removed = File('${file.path}.removed');
      if (await removed.exists()) await removed.delete();
      final temporary = File('${file.path}.tmp');
      await temporary.writeAsBytes(bytes, flush: true);
      if (await file.exists()) await file.delete();
      await temporary.rename(file.path);
      for (final width in decodeWidths) {
        await ResizeImage(FileImage(file), width: width).evict();
      }
      revision++;
      notifyListeners();
      return true;
    } on Object {
      return false;
    }
  }

  Future<void> remove(String id) async {
    try {
      final file = await fileFor(id);
      if (await file.exists()) await file.delete();
      await File('${file.path}.removed').writeAsString('');
      for (final width in decodeWidths) {
        await ResizeImage(FileImage(file), width: width).evict();
      }
      revision++;
      notifyListeners();
    } on Object {
      return;
    }
  }
}
