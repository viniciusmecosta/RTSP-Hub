import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CredentialStore {
  CredentialStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  Future<void> write(String cameraId, String password) async {
    if (password.isEmpty) {
      await delete(cameraId);
      return;
    }
    await _storage.write(key: _key(cameraId), value: password);
  }

  Future<String?> read(String cameraId) async {
    final current = await _storage.read(key: _key(cameraId));
    if (current != null) return current;
    final legacy = await _storage.read(
      key: 'rtsp_view.camera.$cameraId.password',
    );
    if (legacy != null) {
      await _storage.write(key: _key(cameraId), value: legacy);
    }
    return legacy;
  }

  Future<void> delete(String cameraId) async {
    await _storage.delete(key: _key(cameraId));
    await _storage.delete(key: 'rtsp_view.camera.$cameraId.password');
  }

  String _key(String cameraId) => 'rtsp_hub.camera.$cameraId.password';
}
