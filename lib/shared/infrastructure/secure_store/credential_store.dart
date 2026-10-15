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

  Future<String?> read(String cameraId) => _storage.read(key: _key(cameraId));

  Future<void> delete(String cameraId) => _storage.delete(key: _key(cameraId));

  String _key(String cameraId) => 'rtsp_hub.camera.$cameraId.password';
}
