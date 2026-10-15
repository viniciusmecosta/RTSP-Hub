import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rtsp_hub/app/data/app_configuration.dart';
import 'package:rtsp_hub/app/state/app_store.dart';
import 'package:rtsp_hub/features/camera_catalog/data/camera_snapshot_store.dart';
import 'package:rtsp_hub/features/camera_catalog/domain/camera_device.dart';
import 'package:rtsp_hub/shared/infrastructure/secure_store/credential_store.dart';
import 'package:rtsp_hub/shared/infrastructure/storage/config_repository.dart';

class MemoryRepository extends ConfigRepository {
  AppConfiguration value = const AppConfiguration();
  bool fail = false;
  @override
  Future<AppConfiguration> load() async => value;
  @override
  Future<void> save(AppConfiguration config) async {
    if (fail) throw StateError('disk unavailable');
    value = config;
  }
}

class MemoryCredentials extends CredentialStore {
  final values = <String, String>{};
  final reads = <String, int>{};
  bool failRead = false;
  String? failWrite;
  @override
  Future<String?> read(String cameraId) async {
    if (failRead) throw StateError('locked');
    reads.update(cameraId, (count) => count + 1, ifAbsent: () => 1);
    return values[cameraId];
  }

  @override
  Future<void> write(String cameraId, String password) async {
    if (cameraId == failWrite) throw StateError('locked');
    if (password.isEmpty) {
      values.remove(cameraId);
    } else {
      values[cameraId] = password;
    }
  }

  @override
  Future<void> delete(String cameraId) async => values.remove(cameraId);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppStore store;
  late MemoryRepository repository;
  late MemoryCredentials credentials;
  late Directory directory;
  late CameraSnapshotStore snapshots;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('hub-backup-test');
    repository = MemoryRepository();
    credentials = MemoryCredentials();
    snapshots = CameraSnapshotStore(directory: directory);
    store = AppStore(
      repository: repository,
      credentials: credentials,
      snapshotStore: snapshots,
    );
    await store.load();
    expect(
      await store.saveGlobalConnection(
        username: 'global',
        password: 'global:@ç#?',
        port: '8554',
        mainPath: '/global',
        subPath: '/sub',
      ),
      isTrue,
    );
  });
  tearDown(() async {
    store.dispose();
    snapshots.dispose();
    await directory.delete(recursive: true);
  });

  Future<bool> save({
    String id = '',
    String user = '',
    String password = '',
    String path = '',
    String port = '',
    String host = '192.168.1.10',
  }) => store.saveCamera(
    id: id,
    name: 'Portaria',
    host: host,
    port: port,
    username: user,
    password: password,
    mainPath: path,
    subPath: '',
  );

  for (final overrides in [
    ('', '', '/camera'),
    ('specific', '', ''),
    ('', 'specific@:#', ''),
    ('specific', 'specific@:#', '/camera'),
  ]) {
    test(
      'inherits each connection field independently for $overrides',
      () async {
        expect(
          await save(
            user: overrides.$1,
            password: overrides.$2,
            path: overrides.$3,
          ),
          isTrue,
        );
        final camera = store.cameras.single;
        final resolved = store.resolveCamera(camera);
        expect(
          resolved.username,
          overrides.$1.isEmpty ? 'global' : overrides.$1,
        );
        expect(
          resolved.mainPath,
          overrides.$3.isEmpty ? '/global' : overrides.$3,
        );
        expect(resolved.subPath, '/sub');
        expect(resolved.port, 8554);
        expect(
          await store.passwordFor(camera),
          overrides.$2.isEmpty ? 'global:@ç#?' : overrides.$2,
        );
        expect(
          await store.saveGlobalConnection(
            username: 'changed',
            password: 'new',
            port: '554',
            mainPath: '/changed',
          ),
          isTrue,
        );
        expect(
          store.resolveCamera(camera).username,
          overrides.$1.isEmpty ? 'changed' : overrides.$1,
        );
        expect(
          store.resolveCamera(camera).mainPath,
          overrides.$3.isEmpty ? '/changed' : overrides.$3,
        );
        expect(store.resolveCamera(camera).port, 554);
        expect(
          await store.passwordFor(camera),
          overrides.$2.isEmpty ? 'new' : overrides.$2,
        );
      },
    );
  }

  test('clearing a specific password restores global inheritance', () async {
    await save(user: 'operator', password: 'private', port: '9554');
    final id = store.cameras.single.id;
    expect(
      await save(id: id, user: 'operator', password: '', port: '9554'),
      isTrue,
    );
    expect(credentials.values.containsKey(id), isFalse);
    expect(await store.passwordFor(store.cameras.single), 'global:@ç#?');
    expect(store.resolveCamera(store.cameras.single).port, 9554);
  });

  test('legacy global flag does not hide specific field overrides', () async {
    const camera = CameraDevice(
      id: 'legacy',
      name: 'Portaria',
      host: '192.168.1.20',
      mainPath: '',
      username: 'operator',
      useGlobalCredentials: true,
    );
    repository.value = repository.value.copyWith(cameras: [camera]);
    credentials.values[camera.id] = 'specific@:#';
    final reloaded = AppStore(
      repository: repository,
      credentials: credentials,
      snapshotStore: snapshots,
    );
    addTearDown(reloaded.dispose);
    await reloaded.load();

    expect(reloaded.resolveCamera(camera).username, 'operator');
    expect(reloaded.resolveCamera(camera).mainPath, '/global');
    expect(await reloaded.passwordFor(camera), 'specific@:#');
  });

  test('reconnections reuse the known absence of camera credentials', () async {
    expect(await save(), isTrue);
    final camera = store.cameras.single;
    credentials.reads.clear();

    expect(await store.passwordFor(camera), 'global:@ç#?');
    expect(await store.passwordFor(camera), 'global:@ç#?');
    expect(credentials.reads[camera.id], 1);

    expect(await save(id: camera.id, password: 'specific'), isTrue);
    expect(await store.passwordFor(store.cameras.single), 'specific');
  });

  test(
    'global credential cache refreshes after changing the password',
    () async {
      expect(
        await store.saveGlobalConnection(
          username: 'global',
          password: '',
          port: '8554',
          mainPath: '/global',
        ),
        isTrue,
      );
      credentials.reads.clear();

      expect(await store.networkDiscoveryPassword(), isNull);
      expect(await store.networkDiscoveryPassword(), isNull);
      expect(credentials.reads['__network_discovery__'], 1);

      expect(
        await store.saveGlobalConnection(
          username: 'global',
          password: 'new-secret',
          port: '8554',
          mainPath: '/global',
        ),
        isTrue,
      );
      expect(await store.networkDiscoveryPassword(), 'new-secret');
    },
  );

  test('failed camera save restores the previous password', () async {
    await save(password: 'private');
    final id = store.cameras.single.id;
    repository.fail = true;
    expect(await save(id: id), isFalse);
    expect(await store.passwordFor(store.cameras.single), 'private');
  });

  test('failed global save rolls back configuration and credentials', () async {
    repository.fail = true;
    expect(
      await store.saveGlobalConnection(
        username: 'changed',
        password: 'changed',
        port: '554',
        mainPath: '/changed',
      ),
      isFalse,
    );
    expect(store.config.defaultUser, 'global');
    expect(await store.networkDiscoveryPassword(), 'global:@ç#?');
  });

  test(
    'invalid global settings are rejected before accessing storage',
    () async {
      expect(
        await store.saveGlobalConnection(
          username: 'new',
          password: 'new',
          port: '65536',
          mainPath: '/new',
        ),
        isFalse,
      );
      expect(store.config.defaultPort, 8554);
      expect(await store.networkDiscoveryPassword(), 'global:@ç#?');
    },
  );

  test(
    'complete backup clones secrets, photos, profiles and inherited values',
    () async {
      await save(user: 'specific', password: 'p@ss: ç?#', path: '/camera');
      final camera = store.cameras.single;
      final png = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jZ9kAAAAASUVORK5CYII=',
      );
      expect(await snapshots.save(camera.id, png), isTrue);
      await store.saveMonitorProfile(
        name: 'Portaria',
        startupSection: 'monitor',
      );
      final source = await store.exportBackup();
      final destinationDirectory = await Directory.systemTemp.createTemp(
        'hub-destination',
      );
      final destinationSecrets = MemoryCredentials();
      final destinationSnapshots = CameraSnapshotStore(
        directory: destinationDirectory,
      );
      final destination = AppStore(
        repository: MemoryRepository(),
        credentials: destinationSecrets,
        snapshotStore: destinationSnapshots,
      );
      try {
        expect(await destination.importConfiguration(source), isTrue);
        expect(
          await destination.passwordFor(destination.cameras.single),
          'p@ss: ç?#',
        );
        expect(await destination.networkDiscoveryPassword(), 'global:@ç#?');
        expect(destination.config.monitorProfiles.single.name, 'Portaria');
        expect(
          destination.resolveCamera(destination.cameras.single).port,
          8554,
        );
        expect(await destinationSnapshots.read(camera.id), png);
        expect(destination.config.slotCameraIds, store.config.slotCameraIds);
      } finally {
        destination.dispose();
        destinationSnapshots.dispose();
        await destinationDirectory.delete(recursive: true);
      }
    },
  );

  test(
    'restore failure restores secrets and leaves current configuration',
    () async {
      await save(password: 'old');
      final id = store.cameras.single.id;
      final decoded =
          jsonDecode(await store.exportBackup()) as Map<String, dynamic>;
      (decoded['credentials'] as Map)[id] = 'replacement';
      repository.fail = true;
      expect(await store.importConfiguration(jsonEncode(decoded)), isFalse);
      expect(await store.passwordFor(store.cameras.single), 'old');
      expect(store.cameras.single.id, id);
    },
  );

  test(
    'backup refuses missing credentials and malformed images without changes',
    () async {
      await save(password: 'old');
      final decoded =
          jsonDecode(await store.exportBackup()) as Map<String, dynamic>;
      final missing = Map<String, dynamic>.from(decoded)..['credentials'] = {};
      expect(await store.importConfiguration(jsonEncode(missing)), isFalse);
      decoded['thumbnails'] = {
        store.cameras.single.id: base64Encode(Uint8List(30)),
      };
      expect(await store.importConfiguration(jsonEncode(decoded)), isFalse);
      expect(await store.passwordFor(store.cameras.single), 'old');
    },
  );

  test(
    'backup fails explicitly when the secure store cannot be read',
    () async {
      credentials.failRead = true;
      await expectLater(store.exportBackup(), throwsStateError);
    },
  );
}
