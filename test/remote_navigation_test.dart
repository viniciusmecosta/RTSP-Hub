import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rtsp_hub/app/app.dart';
import 'package:rtsp_hub/app/data/app_configuration.dart';
import 'package:rtsp_hub/app/state/app_store.dart';
import 'package:rtsp_hub/features/camera_catalog/domain/camera_device.dart';
import 'package:rtsp_hub/features/monitor/application/rtsp_connection_coordinator.dart';
import 'package:rtsp_hub/features/monitor/application/rtsp_session.dart';
import 'package:rtsp_hub/features/monitor/presentation/monitor_page.dart';
import 'package:rtsp_hub/features/monitor/presentation/widgets/monitor_camera_tile.dart';
import 'package:rtsp_hub/shared/design_system/focusable_surface.dart';
import 'package:rtsp_hub/shared/platform/device_environment.dart';

import 'global_connection_backup_test.dart'
    show MemoryRepository, MemoryCredentials;

class _FakeSession extends RtspSession {
  _FakeSession({
    required super.camera,
    required super.password,
    required super.defaultPort,
    required super.bufferMs,
    required super.useMainStream,
    required RtspConnectionCoordinator connectionCoordinator,
    required int connectionPriority,
  });
  bool released = false;
  @override
  Future<void> start() async {}
  @override
  Future<void> disposeSession() async {
    if (released) return;
    released = true;
    await super.disposeSession();
  }
}

void main() {
  for (final key in [
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.select,
    LogicalKeyboardKey.gameButtonA,
  ]) {
    testWidgets('$key activates a camera without touch', (tester) async {
      var activated = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 300,
              height: 180,
              child: MonitorCameraTile(
                autofocus: true,
                camera: const CameraDevice(
                  id: 'one',
                  name: 'Entrada',
                  host: '10.0.0.1',
                  mainPath: '/main',
                ),
                session: null,
                onTap: () {},
                onFocus: () => activated++,
                onRetry: null,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(key);
      await tester.pump();
      expect(activated, 1);
      expect(
        find.byKey(const ValueKey('keyboard-focus-outline')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('arrows navigate between camera surfaces', (tester) async {
    var selected = -1;
    await tester.pumpWidget(
      MaterialApp(
        home: Row(
          children: [
            for (var index = 0; index < 2; index++)
              Expanded(
                child: FocusableSurface(
                  autofocus: index == 0,
                  onActivate: () => selected = index,
                  child: Text('Camera $index'),
                ),
              ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    expect(selected, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TV paging closes old sessions and resumes the visible page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final cameras = List.generate(
      8,
      (i) => CameraDevice(
        id: 'cam-$i',
        name: 'Câmera $i',
        host: '10.0.0.${i + 1}',
        mainPath: '/main',
        subPath: '/sub',
      ),
    );
    final repo = MemoryRepository()
      ..value = AppConfiguration(
        cameras: cameras,
        layoutId: 'GRID_8',
        slotCameraIds: cameras.map((c) => c.id).toList(),
        tutorialCompleted: true,
      );
    final store = AppStore(repository: repo, credentials: MemoryCredentials());
    addTearDown(store.dispose);
    await store.load();
    final sessions = <_FakeSession>[];
    await tester.pumpWidget(
      DeviceEnvironmentScope(
        environment: const DeviceEnvironment(isTelevision: true),
        child: AppScope(
          store: store,
          child: MaterialApp(
            home: MonitorPage(
              now: tester.binding.clock.now,
              onExit: () {},
              onConfigure: () {},
              sessionFactory:
                  ({
                    required camera,
                    required password,
                    required defaultPort,
                    required bufferMs,
                    required useMainStream,
                    required connectionCoordinator,
                    required connectionPriority,
                  }) {
                    final session = _FakeSession(
                      camera: camera,
                      password: password,
                      defaultPort: defaultPort,
                      bufferMs: bufferMs,
                      useMainStream: useMainStream,
                      connectionCoordinator: connectionCoordinator,
                      connectionPriority: connectionPriority,
                    );
                    sessions.add(session);
                    return session;
                  },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(MonitorCameraTile), findsNWidgets(4));
    expect(sessions.where((s) => !s.released).length, 4);
    expect(sessions.every((s) => !s.useMainStream), isTrue);
    final viewport = find.byKey(const ValueKey('monitorViewport'));
    await tester.tapAt(tester.getCenter(viewport));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Próxima página'));
    await tester.pumpAndSettle();
    expect(store.config.lastMonitorPage, 1);
    expect(sessions.take(4).every((s) => s.released), isTrue);
    expect(sessions.where((s) => !s.released).map((s) => s.camera.id).toSet(), {
      'cam-4',
      'cam-5',
      'cam-6',
      'cam-7',
    });
    final firstTile = find.byKey(const ValueKey('monitor-camera-slot-4'));
    final gesture = find
        .descendant(of: firstTile, matching: find.byType(GestureDetector))
        .first;
    Focus.of(tester.element(gesture)).requestFocus();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    expect(find.byTooltip('Ações do monitor'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Ações do monitor'), findsOneWidget);
    expect(find.byType(MonitorCameraTile), findsNWidgets(4));
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(find.byType(MonitorCameraTile), findsOneWidget);
    expect(sessions.where((s) => !s.released).length, 4);
    expect(
      sessions.where((s) => !s.released).every((s) => !s.useMainStream),
      isTrue,
    );
    expect(sessions.length, 8);
    expect(sessions.where((s) => !s.released && s.isBackground).length, 3);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(MonitorCameraTile), findsNWidgets(4));
    expect(sessions.where((s) => !s.released).length, 4);
    expect(sessions.length, 8);
    expect(
      sessions.where((s) => !s.released).every((s) => !s.isBackground),
      isTrue,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(sessions.every((s) => s.released), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'touching a camera expands it and touching again returns to grid',
    (tester) async {
      tester.view.physicalSize = const Size(960, 540);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final cameras = List.generate(
        4,
        (i) => CameraDevice(
          id: 'c-$i',
          name: 'Cam $i',
          host: '10.0.0.${i + 1}',
          mainPath: '/main',
        ),
      );
      final repo = MemoryRepository()
        ..value = AppConfiguration(
          cameras: cameras,
          layoutId: 'GRID_4',
          slotCameraIds: cameras.map((c) => c.id).toList(),
          tutorialCompleted: true,
        );
      final store = AppStore(
        repository: repo,
        credentials: MemoryCredentials(),
      );
      addTearDown(store.dispose);
      await store.load();
      await tester.pumpWidget(
        AppScope(
          store: store,
          child: MaterialApp(
            home: MonitorPage(
              now: tester.binding.clock.now,
              onExit: () {},
              onConfigure: () {},
              sessionFactory:
                  ({
                    required camera,
                    required password,
                    required defaultPort,
                    required bufferMs,
                    required useMainStream,
                    required connectionCoordinator,
                    required connectionPriority,
                  }) => _FakeSession(
                    camera: camera,
                    password: password,
                    defaultPort: defaultPort,
                    bufferMs: bufferMs,
                    useMainStream: useMainStream,
                    connectionCoordinator: connectionCoordinator,
                    connectionPriority: connectionPriority,
                  ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MonitorCameraTile), findsNWidgets(4));
      final slot0 = find.byKey(const ValueKey('monitor-camera-slot-0'));
      await tester.tap(slot0);
      await tester.pumpAndSettle();
      expect(find.byType(MonitorCameraTile), findsOneWidget);

      await tester.tap(slot0);
      await tester.pumpAndSettle();
      expect(find.byType(MonitorCameraTile), findsNWidgets(4));
    },
  );

  for (final theme in ['light', 'dark']) {
    testWidgets(
      'TV form navigation fits 960x540 in $theme and Back returns home',
      (tester) async {
        tester.view.physicalSize = const Size(960, 540);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repo = MemoryRepository()
          ..value = AppConfiguration(
            startupSection: 'settings',
            tutorialCompleted: true,
            themeMode: theme,
          );
        final store = AppStore(
          repository: repo,
          credentials: MemoryCredentials(),
        );
        await tester.pumpWidget(
          RtspHubApp(
            store: store,
            deviceEnvironment: const DeviceEnvironment(isTelevision: true),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Ajustes'), findsWidgets);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('Visão geral'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
