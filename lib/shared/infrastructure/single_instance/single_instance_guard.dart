import 'dart:io';

class SingleInstanceGuard {
  SingleInstanceGuard._(this._handle);

  final RandomAccessFile _handle;
  bool _released = false;

  static Future<SingleInstanceGuard?> acquire({
    required Directory baseDirectory,
  }) async {
    final directory = Directory(
      '${baseDirectory.path}${Platform.pathSeparator}RTSPView',
    );
    await directory.create(recursive: true);
    final file = File(
      '${directory.path}${Platform.pathSeparator}rtsp-view.lock',
    );
    final handle = await file.open(mode: FileMode.append);
    if (await file.length() == 0) await handle.writeByte(0);
    try {
      await handle.lock(FileLock.exclusive, 0, 1);
      return SingleInstanceGuard._(handle);
    } on FileSystemException {
      await handle.close();
      return null;
    } on Object {
      await handle.close();
      rethrow;
    }
  }

  Future<void> release() async {
    if (_released) return;
    _released = true;
    try {
      await _handle.unlock(0, 1);
    } on Object {
      await _handle.close();
      return;
    }
    await _handle.close();
  }
}
