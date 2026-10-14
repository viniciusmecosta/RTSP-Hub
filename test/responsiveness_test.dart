import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rtsp_view/main.dart';
import 'package:rtsp_view/app/data/app_configuration.dart';
import 'package:rtsp_view/app/state/app_store.dart';
import 'package:rtsp_view/features/camera_catalog/domain/camera_device.dart';
import 'package:rtsp_view/shared/infrastructure/secure_store/credential_store.dart';
import 'package:rtsp_view/shared/infrastructure/storage/config_repository.dart';

void main() {
  const camera = CameraDevice(
    id: 'cam-1',
    name: 'Entrada Principal',
    host: '192.168.1.100',
    mainPath: '/Streaming/Channels/101',
    savedPaths: ['/Streaming/Channels/101', '/Streaming/Channels/102'],
  );

  const config = AppConfiguration(
    startupSection: 'dashboard',
    tutorialCompleted: true,
    cameras: [camera],
  );

  for (final size in [
    const Size(360, 640),
    const Size(768, 1024),
    const Size(1440, 900),
  ]) {
    for (final theme in ['light', 'dark']) {
      testWidgets('native pages fit $size in $theme with larger text', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 1.5;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        for (final section in ['dashboard', 'cameras', 'layouts', 'settings']) {
          await tester.pumpWidget(
            _app(
              configuration: config.copyWith(
                startupSection: section,
                themeMode: theme,
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '$section at $size in $theme',
          );
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        }
      });
    }
  }

  testWidgets('renders properly on compact mobile portrait (360x640)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(_app(configuration: config));
    await tester.pumpAndSettle();

    expect(find.text('Visão geral'), findsOneWidget);
    expect(find.text('Comece pelo essencial'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders properly on mobile landscape (640x360)', (tester) async {
    tester.view.physicalSize = const Size(640, 360);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(_app(configuration: config));
    await tester.pumpAndSettle();

    expect(find.text('Visão geral'), findsOneWidget);
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('navigates across sections without overflow on compact screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(_app(configuration: config));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(NavigationDestination).at(1));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Entrada Principal'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Entrada Principal'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byType(NavigationDestination).at(2));
    await tester.pumpAndSettle();
    expect(find.text('Perfis do monitor'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byType(NavigationDestination).at(4));
    await tester.pumpAndSettle();
    expect(find.text('Conexão padrão'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

MyApp _app({AppConfiguration? configuration}) => MyApp(
  store: AppStore(
    repository: _TestConfigRepository(configuration),
    credentials: _TestCredentialStore(),
  ),
);

class _TestConfigRepository extends ConfigRepository {
  _TestConfigRepository([AppConfiguration? configuration])
    : configuration = configuration ?? const AppConfiguration();

  AppConfiguration configuration;

  @override
  Future<AppConfiguration> load() async => configuration;

  @override
  Future<void> save(AppConfiguration config) async {
    configuration = config;
  }
}

class _TestCredentialStore extends CredentialStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String cameraId) async => values[cameraId];

  @override
  Future<void> write(String cameraId, String password) async {
    values[cameraId] = password;
  }

  @override
  Future<void> delete(String cameraId) async {
    values.remove(cameraId);
  }
}
