import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rtsp_hub/shared/infrastructure/secure_store/credential_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'migrates legacy credentials and clears both names when deleted',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'rtsp_view.camera.camera.password': 'legacy:@ç',
      });
      final credentials = CredentialStore();
      expect(await credentials.read('camera'), 'legacy:@ç');
      expect(
        await const FlutterSecureStorage().read(
          key: 'rtsp_hub.camera.camera.password',
        ),
        'legacy:@ç',
      );
      await credentials.delete('camera');
      expect(await credentials.read('camera'), isNull);
    },
  );
}
