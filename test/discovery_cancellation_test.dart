import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rtsp_hub/features/discovery/application/discovery_cancellation.dart';
import 'package:rtsp_hub/features/discovery/data/onvif_discovery_service.dart';

void main() {
  test('cancellation interrupts outstanding work and is idempotent', () async {
    final token = DiscoveryCancellation();
    final pending = Completer<int>();
    final result = token.bind(pending.future);
    final expectation = expectLater(result, throwsA(isA<DiscoveryCancelled>()));
    token.cancel();
    token.cancel();
    await expectation;
    pending.completeError(StateError('late failure'));
    await Future<void>.delayed(Duration.zero);
    expect(token.isCancelled, isTrue);
  });

  test(
    'ONVIF cancellation closes pending HTTP requests before network timeout',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final requested = Completer<void>();
      final subscription = server.listen((request) {
        if (!requested.isCompleted) requested.complete();
      });
      addTearDown(() async {
        await server.close(force: true);
        await subscription.cancel();
      });
      final token = DiscoveryCancellation();
      final result = OnvifDiscoveryService().loadProfiles(
        OnvifProbeDevice(
          sourceAddress: '127.0.0.1',
          deviceServiceUri: Uri.parse('http://127.0.0.1:${server.port}/onvif'),
          name: null,
        ),
        username: 'admin',
        password: 'secret',
        timeout: const Duration(seconds: 30),
        cancellation: token,
      );
      await requested.future.timeout(const Duration(seconds: 2));
      token.cancel();
      expect(await result.timeout(const Duration(seconds: 1)), isNull);
    },
  );

  test(
    'ONVIF authentication failures are distinct from missing devices',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final subscription = server.listen((request) async {
        await request.drain<void>();
        request.response.statusCode = HttpStatus.unauthorized;
        await request.response.close();
      });
      addTearDown(() async {
        await server.close(force: true);
        await subscription.cancel();
      });
      final result = OnvifDiscoveryService().loadProfiles(
        OnvifProbeDevice(
          sourceAddress: '127.0.0.1',
          deviceServiceUri: Uri.parse('http://127.0.0.1:${server.port}/onvif'),
          name: null,
        ),
        username: 'admin',
        password: 'secret',
      );
      await expectLater(result, throwsA(isA<OnvifAuthenticationFailure>()));
    },
  );
}
