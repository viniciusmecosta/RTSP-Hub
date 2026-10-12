import 'package:flutter_test/flutter_test.dart';
import 'package:rtsp_view/app/data/app_configuration.dart';
import 'package:rtsp_view/app/state/app_store.dart';
import 'package:rtsp_view/shared/infrastructure/secure_store/credential_store.dart';
import 'package:rtsp_view/shared/infrastructure/storage/config_repository.dart';

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
}

class _MemoryRepository extends ConfigRepository {
  final List<AppConfiguration> saved = [];

  @override
  Future<AppConfiguration> load() async => const AppConfiguration();

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
