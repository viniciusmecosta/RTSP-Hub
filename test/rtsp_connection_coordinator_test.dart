import 'package:flutter_test/flutter_test.dart';
import 'package:rtsp_hub/features/monitor/application/rtsp_connection_coordinator.dart';

void main() {
  test(
    'limits handshakes while permitting unlimited running streams',
    () async {
      final coordinator = RtspConnectionCoordinator(
        maxConcurrent: 1,
        spacing: Duration.zero,
      );
      addTearDown(coordinator.dispose);
      final first = await coordinator.request().ready;
      final second = coordinator.request();
      expect(coordinator.activeConnections, 1);
      expect(coordinator.queuedConnections, 1);
      first!.release();
      final next = await second.ready;
      expect(coordinator.activeConnections, 1);
      first.release();
      expect(coordinator.activeConnections, 1);
      next!.release();
      expect(coordinator.activeConnections, 0);
      for (var i = 0; i < 32; i++) {
        final lease = await coordinator.request().ready;
        lease!.release();
      }
    },
  );

  test('focus is prioritized and cancelled requests never open', () async {
    final coordinator = RtspConnectionCoordinator(
      maxConcurrent: 1,
      spacing: Duration.zero,
    );
    addTearDown(coordinator.dispose);
    final active = await coordinator.request().ready;
    final normal = coordinator.request();
    final cancelled = coordinator.request();
    final focus = coordinator.request(priority: 10);
    cancelled.cancel();
    expect(await cancelled.ready, isNull);
    active!.release();
    final focused = await focus.ready;
    expect(coordinator.queuedConnections, 1);
    focused!.release();
    (await normal.ready)!.release();
    expect(coordinator.activeConnections, 0);
  });

  test(
    'disposing releases pending requests without starting new players',
    () async {
      final coordinator = RtspConnectionCoordinator(
        maxConcurrent: 1,
        spacing: Duration.zero,
      );
      final active = await coordinator.request().ready;
      final waiting = coordinator.request();
      coordinator.dispose();
      expect(await waiting.ready, isNull);
      expect(await coordinator.request().ready, isNull);
      active!.release();
      expect(coordinator.activeConnections, 0);
    },
  );

  test('spaces the starts of simultaneous reconnections', () async {
    final coordinator = RtspConnectionCoordinator(
      maxConcurrent: 2,
      spacing: const Duration(milliseconds: 40),
    );
    addTearDown(coordinator.dispose);
    final first = await coordinator.request().ready;
    final clock = Stopwatch()..start();
    final second = await coordinator.request().ready;
    expect(clock.elapsedMilliseconds, greaterThanOrEqualTo(30));
    first!.release();
    second!.release();
  });
}
