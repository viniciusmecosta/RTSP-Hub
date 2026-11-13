import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:rtsp_hub/app/data/app_configuration.dart';
import 'package:rtsp_hub/app/data/transfer_codec.dart';
import 'package:rtsp_hub/app/state/app_store.dart';
import 'global_connection_backup_test.dart'
    show MemoryRepository, MemoryCredentials;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppStore sender, receiver;
  late MemoryRepository receiverRepo;
  late MemoryCredentials receiverSecrets;
  setUp(() async {
    sender = AppStore(
      repository: MemoryRepository(),
      credentials: MemoryCredentials(),
    );
    receiverRepo = MemoryRepository();
    receiverSecrets = MemoryCredentials();
    receiver = AppStore(repository: receiverRepo, credentials: receiverSecrets);
    await sender.load();
    await receiver.load();
    await sender.saveGlobalConnection(
      username: 'operador',
      password: 'p@ss: ç#?',
      port: '8554',
      mainPath: '/main',
      subPath: '/sub',
    );
    await sender.saveCamera(
      id: '',
      name: 'Portão',
      host: '10.0.0.8',
      port: '',
      username: '',
      password: '',
      mainPath: '',
      subPath: '',
    );
    await sender.saveMonitorProfile(name: 'Casa');
  });
  tearDown(() {
    sender.dispose();
    receiver.dispose();
  });

  test(
    'profile carries effective connection and credentials through compact code',
    () async {
      final source = await sender.exportPortableProfile(
        sender.config.monitorProfiles.single.id,
        includeCredentials: true,
      );
      final code = TransferCodec.encode(source);
      expect(code.length, lessThan(TransferCodec.maxQrCharacters));
      expect(await receiver.importMonitorProfiles(code), 1);
      final camera = receiver.cameras.single;
      expect(camera.id, isNot(sender.cameras.single.id));
      expect(camera.port, 8554);
      expect(camera.mainPath, '/main');
      expect(camera.subPath, '/sub');
      expect(camera.username, 'operador');
      expect(await receiver.passwordFor(camera), 'p@ss: ç#?');
      expect(
        await receiver.applyMonitorProfile(
          receiver.config.monitorProfiles.single.id,
        ),
        isTrue,
      );
      expect(receiver.config.slotCameraIds.first, camera.id);
    },
  );

  test('credentials are absent unless explicitly included', () async {
    final source = await sender.exportPortableProfiles(
      includeCredentials: false,
    );
    final decoded = jsonDecode(source) as Map;
    expect(decoded.containsKey('credentials'), isFalse);
    expect(decoded['cameras'][0]['username'], '');
    expect(source, isNot(contains('operador')));
    expect(source, isNot(contains('p@ss')));
    expect(await receiver.importMonitorProfiles(source), 1);
    expect(receiverSecrets.values, isEmpty);
  });

  test('failed config write rolls imported credentials back', () async {
    final source = await sender.exportPortableProfiles(
      includeCredentials: true,
    );
    receiverRepo.fail = true;
    expect(await receiver.importMonitorProfiles(source), isNull);
    expect(receiverSecrets.values, isEmpty);
    expect(receiver.cameras, isEmpty);
    expect(receiver.config.monitorProfiles, isEmpty);
  });

  test(
    'invalid credential references never write configuration or secrets',
    () async {
      final decoded =
          jsonDecode(
                await sender.exportPortableProfiles(includeCredentials: true),
              )
              as Map<String, dynamic>;
      decoded['credentials'] = {'missing-camera': 'secret'};
      expect(await receiver.importMonitorProfiles(jsonEncode(decoded)), isNull);
      expect(receiverSecrets.values, isEmpty);
      expect(receiver.config.monitorProfiles, isEmpty);
    },
  );

  test(
    'reimport preserves local passwords for cameras already present',
    () async {
      final source = await sender.exportPortableProfiles(
        includeCredentials: true,
      );
      expect(await receiver.importMonitorProfiles(source), 1);
      final camera = receiver.cameras.single;
      receiverSecrets.values[camera.id] = 'local-password';
      expect(await receiver.importMonitorProfiles(source), 1);
      expect(receiver.cameras.length, 1);
      expect(receiverSecrets.values[camera.id], 'local-password');
      expect(receiver.config.monitorProfiles.map((p) => p.name), [
        'Casa',
        'Casa (2)',
      ]);
    },
  );

  test(
    'portable profiles preserve custom geometry and camera references',
    () async {
      await sender.setLayout('FREEFORM');
      await sender.addFreeformSlot();
      await sender.saveMonitorProfile(name: 'Personalizado');
      final source = await sender.exportPortableProfile(
        sender.config.monitorProfiles.last.id,
        includeCredentials: false,
      );
      expect(await receiver.importMonitorProfiles(source), 1);
      final imported = receiver.config.monitorProfiles.single;
      expect(imported.freeformSlots.length, sender.config.freeformSlots.length);
      expect(imported.freeformSlots.first.cameraId, receiver.cameras.single.id);
      expect(await receiver.applyMonitorProfile(imported.id), isTrue);
      expect(receiver.config.freeformSlots, imported.freeformSlots);
    },
  );

  test('unknown transfer versions do not change the receiver', () async {
    expect(await receiver.importMonitorProfiles('RTH2:anything'), isNull);
    expect(receiverRepo.value.cameras, const AppConfiguration().cameras);
  });
}
