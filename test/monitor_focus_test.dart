import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rtsp_hub/app/data/app_configuration.dart';
import 'package:rtsp_hub/app/state/app_store.dart';
import 'package:rtsp_hub/features/camera_catalog/domain/camera_device.dart';
import 'package:rtsp_hub/features/layouts/domain/freeform_slot.dart';
import 'package:rtsp_hub/features/monitor/application/rtsp_session.dart';
import 'package:rtsp_hub/features/monitor/presentation/monitor_page.dart';
import 'package:rtsp_hub/features/monitor/presentation/widgets/monitor_camera_tile.dart';
import 'package:rtsp_hub/shared/design_system/focusable_surface.dart';

import 'global_connection_backup_test.dart'
    show MemoryRepository, MemoryCredentials;

class _Session extends RtspSession {
  _Session({
    required super.camera,
    required super.password,
    required super.defaultPort,
    required super.bufferMs,
    required super.useMainStream,
    this.blocked,
  });

  final Completer<void>? blocked;
  int starts = 0;
  bool released = false;

  @override
  Future<void> start() async {
    starts++;
    await blocked?.future;
  }

  @override
  Future<void> disposeSession() async {
    if (released) return;
    released = true;
    if (blocked?.isCompleted == false) blocked!.complete();
    await super.disposeSession();
  }
}

Future<({AppStore store, List<_Session> sessions})> _openMonitor(
  WidgetTester tester, {
  String layout = 'GRID_4',
  bool simple = false,
  String resourceMode = 'balanced',
  Completer<void>? blocked,
}) async {
  final cameras = List.generate(
    4,
    (index) => CameraDevice(
      id: 'cam-$index',
      name: 'Câmera $index',
      host: '10.0.0.${index + 1}',
      mainPath: '/main',
      subPath: '/sub',
    ),
  );
  final repo = MemoryRepository()
    ..value = AppConfiguration(
      simpleMode: simple,
      cameras: cameras,
      layoutId: layout,
      resourceMode: resourceMode,
      slotCameraIds: cameras.map((camera) => camera.id).toList(),
      freeformSlots: [
        for (var index = 0; index < 4; index++)
          FreeformSlot(
            cameraId: cameras[index].id,
            x: (index % 2) * 0.5,
            y: (index ~/ 2) * 0.5,
          ),
      ],
      tutorialCompleted: true,
    );
  final store = AppStore(repository: repo, credentials: MemoryCredentials());
  addTearDown(store.dispose);
  await store.load();
  final sessions = <_Session>[];
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
              }) {
                final session = _Session(
                  camera: camera,
                  password: password,
                  defaultPort: defaultPort,
                  bufferMs: bufferMs,
                  useMainStream: useMainStream,
                  blocked: camera.id == 'cam-0' ? blocked : null,
                );
                sessions.add(session);
                return session;
              },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (store: store, sessions: sessions);
}

void main() {
  testWidgets('simple monitor changes cells and upgrades focused stream', (
    tester,
  ) async {
    final monitor = await _openMonitor(tester, simple: true);
    expect(
      monitor.sessions.where((s) => !s.released).every((s) => !s.useMainStream),
      isTrue,
    );
    final tile = find.byKey(const ValueKey('monitor-camera-slot-0'));
    await tester.tap(tile);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.text('Câmera da posição 1'), findsOneWidget);
    await tester.tap(find.byTooltip('Fechar seleção'));
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(tile);
    await tester.pumpAndSettle();
    final playing = monitor.sessions.where((s) => !s.released).toList();
    expect(playing.length, 1);
    expect(playing.single.useMainStream, isTrue);
    await tester.tap(tile);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(monitor.sessions.where((s) => !s.released).length, 4);
    expect(
      monitor.sessions.where((s) => !s.released).every((s) => !s.useMainStream),
      isTrue,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('an empty page cannot focus a camera from another page', (
    tester,
  ) async {
    final monitor = await _openMonitor(tester);
    await monitor.store.updateSettings(monitorPageSize: 2);
    await monitor.store.setSlot(0, null);
    await monitor.store.setSlot(1, null);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ampliar câmera selecionada'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Voltar à grade'), findsNothing);
    expect(monitor.sessions.where((s) => !s.released), isEmpty);
    await tester.tap(find.byTooltip('Próxima página'));
    await tester.pumpAndSettle();
    expect(monitor.sessions.where((s) => !s.released).length, 2);
    expect(
      monitor.sessions.where((s) => !s.released).every((s) => !s.isBackground),
      isTrue,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  for (final size in [
    const Size(360, 640),
    const Size(800, 1280),
    const Size(1440, 900),
  ]) {
    for (final layout in ['GRID_4', 'FOCUS_RIGHT_3', 'FREEFORM']) {
      testWidgets(
        '$layout at $size retains sessions and video elements during focus',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final monitor = await _openMonitor(tester, layout: layout);
          final elements = [
            for (var index = 0; index < 4; index++)
              tester.element(
                find.byKey(ValueKey('monitor-camera-slot-$index')),
              ),
          ];
          final surfaces = [
            for (var index = 0; index < 4; index++)
              tester.element(
                find.descendant(
                  of: find.byKey(ValueKey('monitor-camera-slot-$index')),
                  matching: find.byType(FocusableSurface),
                ),
              ),
          ];
          final gridRects = [
            for (var index = 0; index < 4; index++)
              tester.getRect(
                find.byKey(ValueKey('monitor-camera-slot-$index')),
              ),
          ];
          for (var iteration = 0; iteration < 3; iteration++) {
            final slot = find.byKey(ValueKey('monitor-camera-slot-$iteration'));
            await tester.tap(slot);
            await tester.pumpAndSettle();
            expect(find.byType(MonitorCameraTile), findsOneWidget);
            expect(tester.getRect(slot), Offset.zero & size);
            expect(monitor.sessions.length, 4);
            expect(
              monitor.sessions.every((s) => s.starts == 1 && !s.released),
              isTrue,
            );
            expect(monitor.sessions.where((s) => s.isBackground).length, 3);
            expect(monitor.sessions[iteration].isBackground, isFalse);
            expect(monitor.sessions.every((s) => !s.useMainStream), isTrue);
            expect(
              find.byType(MonitorCameraTile, skipOffstage: false),
              findsNWidgets(4),
            );
            for (var index = 0; index < 4; index++) {
              final tile = find.byKey(
                ValueKey('monitor-camera-slot-$index'),
                skipOffstage: false,
              );
              expect(tester.element(tile), same(elements[index]));
              final surface = find.descendant(
                of: tile,
                matching: find.byType(FocusableSurface, skipOffstage: false),
                skipOffstage: false,
              );
              expect(tester.element(surface), same(surfaces[index]));
              expect(
                TickerMode.valuesOf(tester.element(surface)).enabled,
                index == iteration,
              );
              if (index != iteration) {
                expect(
                  Focus.of(tester.element(surface)).descendantsAreFocusable,
                  isFalse,
                );
              }
            }
            if (iteration == 0) {
              await tester.tap(slot);
            } else if (iteration == 1) {
              await tester.sendKeyEvent(LogicalKeyboardKey.escape);
            } else {
              await tester.tap(find.byTooltip('Voltar à grade'));
            }
            await tester.pumpAndSettle();
            expect(find.byType(MonitorCameraTile), findsNWidgets(4));
            expect(
              monitor.sessions.every(
                (s) => !s.isBackground && s.starts == 1 && !s.released,
              ),
              isTrue,
            );
            for (var index = 0; index < 4; index++) {
              final tile = find.byKey(ValueKey('monitor-camera-slot-$index'));
              expect(tester.element(tile), same(elements[index]));
              expect(tester.getRect(tile), gridRects[index]);
            }
          }
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
          expect(monitor.sessions.every((s) => s.released), isTrue);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('an unavailable camera does not delay other sessions or focus', (
    tester,
  ) async {
    final blocked = Completer<void>();
    final monitor = await _openMonitor(tester, blocked: blocked);
    expect(blocked.isCompleted, isFalse);
    expect(monitor.sessions.length, 4);
    expect(monitor.sessions.every((session) => session.starts == 1), isTrue);
    final healthy = find.byKey(const ValueKey('monitor-camera-slot-1'));
    await tester.tap(healthy);
    await tester.pumpAndSettle();
    monitor.sessions.first.status.value = CameraPlaybackStatus.error;
    monitor.sessions.first.error.value = 'Sem conexão';
    await tester.pumpAndSettle();
    expect(find.byType(MonitorCameraTile), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(MonitorCameraTile), findsNWidgets(4));
    expect(monitor.sessions.every((s) => s.starts == 1 && !s.released), isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(blocked.isCompleted, isTrue);
  });

  testWidgets('manual HD still replaces streams and preserves focus', (
    tester,
  ) async {
    final monitor = await _openMonitor(tester);
    final slot = find.byKey(const ValueKey('monitor-camera-slot-0'));
    await tester.tap(slot);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('monitor-stream-hd')));
    await tester.pumpAndSettle();
    expect(monitor.sessions.length, 8);
    expect(monitor.sessions.take(4).every((s) => s.released), isTrue);
    expect(monitor.sessions.skip(4).every((s) => s.useMainStream), isTrue);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(monitor.sessions.length, 8);
    expect(find.byType(MonitorCameraTile), findsNWidgets(4));
    expect(
      monitor.sessions.skip(4).every((s) => !s.isBackground && !s.released),
      isTrue,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('backgrounding the app releases sessions and resumes only once', (
    tester,
  ) async {
    final monitor = await _openMonitor(tester);
    await tester.tap(find.byKey(const ValueKey('monitor-camera-slot-1')));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pumpAndSettle();
    expect(monitor.sessions.every((s) => s.released), isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(monitor.sessions.length, 8);
    expect(monitor.sessions.skip(4).where((s) => s.isBackground).length, 3);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(monitor.sessions.length, 8);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
