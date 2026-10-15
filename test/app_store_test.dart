import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rtsp_hub/features/camera_catalog/domain/camera_device.dart';
import 'package:rtsp_hub/app/data/app_configuration.dart';
import 'package:rtsp_hub/app/state/app_store.dart';
import 'package:rtsp_hub/shared/infrastructure/secure_store/credential_store.dart';
import 'package:rtsp_hub/shared/infrastructure/storage/config_repository.dart';

void main() {
  late _MemoryRepository repository;
  late _MemoryCredentials credentials;
  late AppStore store;

  setUp(() {
    repository = _MemoryRepository();
    credentials = _MemoryCredentials();
    store = AppStore(repository: repository, credentials: credentials);
  });

  tearDown(() => store.dispose());

  Future<bool> saveCamera({
    String host = '192.168.1.10',
    String port = '554',
    String mainPath = '/stream',
    String password = '',
  }) => store.saveCamera(
    id: '',
    name: 'Câmera teste',
    host: host,
    port: port,
    username: 'operator',
    password: password,
    mainPath: mainPath,
    subPath: '',
  );

  test('nova câmera sem dados herda conexão global', () async {
    await store.updateSettings(defaultPort: 8554, defaultPath: '/global');
    final saved = await store.saveCamera(
      id: '',
      name: '',
      host: '192.168.1.30',
      port: '',
      username: '',
      password: '',
      mainPath: '',
      subPath: '',
    );

    expect(saved, isTrue);
    final camera = store.cameras.single;
    expect(camera.useGlobalCredentials, isTrue);
    expect(camera.port, isNull);
    expect(camera.effectivePort(store.config.defaultPort), 8554);
    expect(camera.mainPath, isEmpty);
    expect(store.resolveCamera(camera).mainPath, '/global');
  });

  test(
    'clona câmera copiando credenciais e configurações e alterando apenas o host',
    () async {
      await store.saveCamera(
        id: '',
        name: 'Portão 1',
        host: '192.168.1.10',
        port: '8554',
        username: 'admin',
        password: 'secret',
        mainPath: '/live/main',
        subPath: '/live/sub',
      );
      final source = store.cameras.single;
      final success = await store.cloneCamera(source, newHost: '192.168.1.11');

      expect(success, isTrue);
      expect(store.cameras, hasLength(2));
      final clone = store.cameras.last;
      expect(clone.name, 'Portão 1 (cópia)');
      expect(clone.host, '192.168.1.11');
      expect(clone.port, 8554);
      expect(clone.username, 'admin');
      expect(clone.mainPath, '/live/main');
      expect(clone.subPath, '/live/sub');
      expect(await store.passwordFor(clone), 'secret');
    },
  );

  test('exporta e importa perfis com as câmeras usadas', () async {
    await saveCamera();
    await store.setSlot(0, store.cameras.single.id);
    await store.saveMonitorProfile(name: 'Portaria');
    final exported = store.exportMonitorProfiles();
    expect(exported, isNot(contains('password')));

    final other = AppStore(
      repository: _MemoryRepository(),
      credentials: _MemoryCredentials(),
    );
    addTearDown(other.dispose);
    final added = await other.importMonitorProfiles(exported);

    expect(added, 1);
    expect(other.cameras.single.host, '192.168.1.10');
    final profile = other.config.monitorProfiles.single;
    expect(profile.name, 'Portaria');
    expect(profile.slotCameraIds.first, other.cameras.single.id);

    final again = await other.importMonitorProfiles(exported);
    expect(again, 1);
    expect(other.cameras, hasLength(1));
    expect(other.config.monitorProfiles.last.name, 'Portaria (2)');
  });

  test('recusa arquivo que não é exportação de perfis', () async {
    expect(await store.importMonitorProfiles('{"cameras": []}'), isNull);
  });

  test(
    'perfil exportado preserva a porta efetiva e o tipo de credencial',
    () async {
      await store.updateSettings(defaultPort: 8554);
      final saved = await store.saveCamera(
        id: '',
        name: 'Portaria',
        host: '192.168.1.42',
        port: '',
        username: 'operador',
        password: 'senha-local',
        mainPath: '/live/main',
        subPath: '/live/sub',
      );
      expect(saved, isTrue);
      await store.setSlot(0, store.cameras.single.id);
      await store.saveMonitorProfile(name: 'Noite');
      final exported = store.exportMonitorProfiles();
      final decoded = jsonDecode(exported) as Map<String, dynamic>;
      expect(decoded['version'], 2);
      expect((decoded['cameras'] as List).single['port'], 8554);
      expect(exported, isNot(contains('senha-local')));

      final other = AppStore(
        repository: _MemoryRepository(),
        credentials: _MemoryCredentials(),
      );
      addTearDown(other.dispose);
      expect(await other.importMonitorProfiles(exported), 1);
      expect(
        other.cameras.single.effectivePort(other.config.defaultPort),
        8554,
      );
      expect(other.cameras.single.useGlobalCredentials, isFalse);
      expect(other.cameras.single.username, 'operador');
      expect(await other.passwordFor(other.cameras.single), isNull);
    },
  );

  test(
    'rejeita perfil com câmera inexistente sem alterar configuração',
    () async {
      final invalid = jsonEncode({
        'format': AppStore.profileExportFormat,
        'version': 2,
        'cameras': [],
        'profiles': [
          {
            'id': 'perfil-1',
            'name': 'Portaria',
            'layoutId': 'GRID_4',
            'slotCameraIds': ['camera-ausente', null, null, null],
          },
        ],
      });

      expect(await store.importMonitorProfiles(invalid), isNull);
      expect(store.config.monitorProfiles, isEmpty);
    },
  );

  test('rejects host values that contain URLs or invalid DNS labels', () async {
    final url = await saveCamera(host: 'rtsp://192.168.1.10');
    final invalidDns = await saveCamera(host: 'camera..local');

    expect(url, isFalse);
    expect(invalidDns, isFalse);
    expect(repository.saved, isEmpty);
  });

  test('rejects ports outside the TCP port range', () async {
    final tooLow = await saveCamera(port: '0');
    final tooHigh = await saveCamera(port: '65536');
    final notNumeric = await saveCamera(port: 'abc');

    expect(tooLow, isFalse);
    expect(tooHigh, isFalse);
    expect(notNumeric, isFalse);
    expect(repository.saved, isEmpty);
  });

  test('rejects RTSP paths containing a scheme or fragment', () async {
    final scheme = await saveCamera(mainPath: 'rtsp://camera/live');
    final fragment = await saveCamera(mainPath: '/live#channel');

    expect(scheme, isFalse);
    expect(fragment, isFalse);
    expect(repository.saved, isEmpty);
  });

  test('stores valid camera configuration without its password', () async {
    final saved = await saveCamera(
      host: 'camera.local',
      password: 'private-secret',
      mainPath: '/stream/main',
    );

    expect(saved, isTrue);
    expect(store.cameras, hasLength(1));
    expect(store.cameras.single.host, 'camera.local');
    expect(store.config.slotCameraIds.first, store.cameras.single.id);
    expect(credentials.values.values.single, 'private-secret');
    expect(
      repository.saved.single.toJson().toString(),
      isNot(contains('private-secret')),
    );
  });

  test('stores network discovery credentials globally and securely', () async {
    final saved = await store.saveNetworkDiscoveryCredentials(
      username: 'monitor',
      password: 'shared-secret',
    );

    expect(saved, isTrue);
    expect(store.config.defaultUser, 'monitor');
    expect(credentials.values['__network_discovery__'], 'shared-secret');
    expect(
      repository.saved.last.toJson().toString(),
      isNot(contains('shared-secret')),
    );
    expect(await store.networkDiscoveryPassword(), 'shared-secret');
  });

  test('adds discovered channels with one configuration write', () async {
    final added = await store.addDiscoveredCameras([
      const CameraDevice(
        id: '',
        name: 'Canal 1',
        host: '192.168.1.5',
        port: 554,
        mainPath: '/Streaming/Channels/101',
      ),
      const CameraDevice(
        id: '',
        name: 'Canal 2',
        host: '192.168.1.5',
        port: 554,
        mainPath: '/Streaming/Channels/201',
      ),
      const CameraDevice(
        id: '',
        name: 'Duplicada',
        host: '192.168.1.5',
        port: 554,
        mainPath: '/Streaming/Channels/101',
      ),
    ]);

    expect(added, 2);
    expect(repository.saved, hasLength(1));
    expect(store.cameras, hasLength(2));
    expect(
      store.cameras.every((camera) => camera.useGlobalCredentials),
      isTrue,
    );
    expect(
      store.config.slotCameraIds.take(2),
      store.cameras.map((camera) => camera.id),
    );
    expect(credentials.values, isEmpty);
  });

  test(
    'camera can reference global credentials without duplicating secrets',
    () async {
      await store.saveNetworkDiscoveryCredentials(
        username: 'shared-user',
        password: 'shared-secret',
      );
      final saved = await store.saveCamera(
        id: '',
        name: 'Câmera global',
        host: 'camera-global.local',
        port: '554',
        username: 'shared-user',
        password: 'shared-secret',
        mainPath: '/stream',
        subPath: '',
        useGlobalCredentials: true,
      );

      expect(saved, isTrue);
      expect(store.cameras.single.useGlobalCredentials, isTrue);
      expect(await store.passwordFor(store.cameras.single), 'shared-secret');
      expect(credentials.values.keys, ['__network_discovery__']);
    },
  );

  test(
    'rejects duplicate camera addresses regardless of letter case',
    () async {
      expect(
        await saveCamera(host: 'Camera.Local', mainPath: '/channel/1'),
        isTrue,
      );
      expect(
        await saveCamera(host: 'camera.local', mainPath: '/channel/1'),
        isFalse,
      );
      expect(store.cameras, hasLength(1));
    },
  );

  test('allows multiple channels from the same recorder address', () async {
    expect(
      await saveCamera(host: 'recorder.local', mainPath: '/channel/1'),
      isTrue,
    );
    expect(
      await saveCamera(host: 'recorder.local', mainPath: '/channel/2'),
      isTrue,
    );
    expect(store.cameras, hasLength(2));
    expect(store.config.slotCameraIds[0], store.cameras[0].id);
    expect(store.config.slotCameraIds[1], store.cameras[1].id);
  });

  test(
    'saves and restores a monitor profile with its camera assignments',
    () async {
      await saveCamera(host: 'cam-a.local', mainPath: '/channel/1');
      await saveCamera(host: 'cam-b.local', mainPath: '/channel/2');
      await store.setLayout('GRID_2H');
      final saved = await store.saveMonitorProfile(
        name: 'Portaria',
        startupSection: 'monitor',
      );
      await store.setLayout('SINGLE');
      await store.applyMonitorProfile(store.config.monitorProfiles.single.id);

      expect(saved, isTrue);
      expect(store.activeLayout.id, 'GRID_2H');
      expect(store.config.slotCameraIds, [
        store.cameras.first.id,
        store.cameras.last.id,
      ]);
      expect(repository.saved.last.monitorProfiles.single.name, 'Portaria');
      expect(store.config.startupSection, 'monitor');
    },
  );

  test('rejects empty and duplicate monitor profile names', () async {
    expect(await store.saveMonitorProfile(name: '  '), isFalse);
    expect(await store.saveMonitorProfile(name: 'Noite'), isTrue);
    expect(await store.saveMonitorProfile(name: 'noite'), isFalse);
    expect(store.config.monitorProfiles, hasLength(1));
  });

  test('configuration backups exclude secrets and can be restored', () async {
    await saveCamera(password: 'private-secret');
    final backup = store.exportConfiguration();
    expect(backup, isNot(contains('private-secret')));
    await store.removeCamera(store.cameras.single.id);

    final imported = await store.importConfiguration(backup);

    expect(imported, isTrue);
    expect(store.cameras, hasLength(1));
    expect(store.cameras.single.host, '192.168.1.10');
    expect(await store.passwordFor(store.cameras.single), isNull);
  });

  test(
    'rejects malformed configuration backups without replacing settings',
    () async {
      await saveCamera(host: 'cam-keep.local');
      final imported = await store.importConfiguration('{invalid');

      expect(imported, isFalse);
      expect(store.cameras.single.host, 'cam-keep.local');
    },
  );

  test('persists the selected startup section', () async {
    await store.updateSettings(
      startupSection: 'last',
      lastSection: 'monitor',
      lastMonitorPage: 2,
    );

    expect(store.config.startupSection, 'last');
    expect(store.config.lastSection, 'monitor');
    expect(store.config.lastMonitorPage, 2);
    expect(
      repository.saved.last.toJson()['settings'],
      containsPair('startupSection', 'last'),
    );
  });

  test('keeps settings from concurrent updates', () async {
    await Future.wait([
      store.updateSettings(lastSection: 'monitor'),
      store.updateSettings(lastMonitorPage: 3),
      store.updateSettings(resourceMode: 'balanced'),
    ]);

    expect(store.config.lastSection, 'monitor');
    expect(store.config.lastMonitorPage, 3);
    expect(store.config.resourceMode, 'balanced');
  });

  test('removes assignments to cameras missing from saved data', () async {
    repository.initial = const AppConfiguration(
      slotCameraIds: ['missing', null, null, null],
    );
    await store.load();

    expect(store.config.slotCameraIds, [null, null, null, null]);
  });

  test('starts with automatic destination for existing installations', () {
    expect(const AppConfiguration().startupSection, 'auto');
    expect(
      AppConfiguration.fromJson(
        const AppConfiguration().toJson().cast<String, Object?>(),
      ).startupSection,
      'auto',
    );
  });

  test('preserves dashboard as an explicit startup destination', () {
    final configuration = AppConfiguration.fromJson({
      ...const AppConfiguration().toJson().cast<String, Object?>(),
      'settings': {'startupSection': 'dashboard'},
    });

    expect(configuration.startupSection, 'dashboard');
  });

  test('moves the removed discovery startup destination to automatic', () {
    final configuration = AppConfiguration.fromJson({
      ...const AppConfiguration().toJson().cast<String, Object?>(),
      'settings': {'startupSection': 'discovery'},
    });

    expect(configuration.startupSection, 'auto');
  });

  test('persists completion of the first-run tutorial', () {
    final configuration = const AppConfiguration().copyWith(
      tutorialCompleted: true,
    );
    final restored = AppConfiguration.fromJson(
      configuration.toJson().cast<String, Object?>(),
    );

    expect(const AppConfiguration().tutorialCompleted, isFalse);
    expect(restored.tutorialCompleted, isTrue);
  });

  test(
    'persists multiple channels in camera and allows switching active channel',
    () async {
      final saved = await store.saveCamera(
        id: '',
        name: 'NVR Entrada',
        host: '192.168.1.100',
        port: '554',
        username: 'admin',
        password: '',
        mainPath: '/Streaming/Channels/101',
        subPath: '/Streaming/Channels/102',
        savedPaths: [
          '/Streaming/Channels/101',
          '/Streaming/Channels/201',
          '/Streaming/Channels/301',
        ],
      );

      expect(saved, isTrue);
      final camera = store.cameras.single;
      expect(camera.mainPath, '/Streaming/Channels/101');
      expect(
        camera.savedPaths,
        containsAll([
          '/Streaming/Channels/101',
          '/Streaming/Channels/102',
          '/Streaming/Channels/201',
          '/Streaming/Channels/301',
        ]),
      );

      expect(
        await store.switchCameraChannel(camera.id, '/Streaming/Channels/201'),
        isTrue,
      );
      final updated = store.cameras.single;
      expect(updated.mainPath, '/Streaming/Channels/101');
      expect(updated.subPath, '/Streaming/Channels/102');
      expect(updated.selectedPath, '/Streaming/Channels/201');
      expect(
        updated.playbackPath(useMainStream: false),
        '/Streaming/Channels/201',
      );
      expect(
        updated.playbackPath(useMainStream: true),
        '/Streaming/Channels/201',
      );
      expect(updated.savedPaths, contains('/Streaming/Channels/101'));
      expect(await store.switchCameraChannel(camera.id, '/unlisted'), isFalse);
      expect(store.cameras.single.selectedPath, '/Streaming/Channels/201');
    },
  );

  test('camera model serializes and restores savedPaths', () {
    const original = CameraDevice(
      id: 'cam1',
      name: 'Entrada',
      host: '192.168.1.50',
      mainPath: '/ch1',
      savedPaths: ['/ch1', '/ch2', '/ch3'],
      selectedPath: '/ch2',
    );
    final json = original.toJson();
    final restored = CameraDevice.fromJson(json);

    expect(restored.savedPaths, ['/ch1', '/ch2', '/ch3']);
    expect(restored.selectedPath, '/ch2');
  });

  test('grade dinâmica mantém todas as câmeras e preserva a ordem', () async {
    for (var index = 1; index <= 17; index++) {
      expect(await saveCamera(host: '192.168.2.$index'), isTrue);
    }
    await store.setLayout('GRID_ALL');

    expect(store.activeLayout.cameraCount, 17);
    expect(store.config.slotCameraIds, hasLength(17));
    expect(
      store.config.slotCameraIds.whereType<String>().toSet(),
      store.cameras.map((camera) => camera.id).toSet(),
    );

    final first = store.config.slotCameraIds.first;
    final second = store.config.slotCameraIds[1];
    await store.setSlot(0, second);
    expect(store.config.slotCameraIds.first, second);
    expect(store.config.slotCameraIds[1], first);

    expect(await saveCamera(host: '192.168.2.18'), isTrue);
    expect(store.config.slotCameraIds, hasLength(18));
    await store.removeCamera(second!);
    expect(store.config.slotCameraIds, hasLength(17));
    expect(store.config.slotCameraIds, isNot(contains(second)));

    final restored = AppConfiguration.fromJson(store.config.toJson());
    expect(restored.layoutId, 'GRID_ALL');
    expect(restored.slotCameraIds, hasLength(17));
  });
}

class _MemoryRepository extends ConfigRepository {
  final List<AppConfiguration> saved = [];
  AppConfiguration initial = const AppConfiguration();

  @override
  Future<AppConfiguration> load() async => initial;

  @override
  Future<void> save(AppConfiguration config) async {
    saved.add(config);
  }
}

class _MemoryCredentials extends CredentialStore {
  final Map<String, String> values = {};

  @override
  Future<void> write(String cameraId, String password) async {
    values[cameraId] = password;
  }

  @override
  Future<String?> read(String cameraId) async => values[cameraId];

  @override
  Future<void> delete(String cameraId) async {
    values.remove(cameraId);
  }
}
