import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rtsp_hub/shared/platform/device_environment.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(DeviceEnvironment.channel, null);
  });

  for (final television in [true, false]) {
    test(
      'Android reports television=$television independently of size',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(DeviceEnvironment.channel, (call) async {
              expect(call.method, 'isTelevision');
              return television;
            });
        expect((await DeviceEnvironment.load()).isTelevision, television);
      },
    );
  }

  for (final platform in [
    TargetPlatform.linux,
    TargetPlatform.windows,
    TargetPlatform.iOS,
    TargetPlatform.macOS,
  ]) {
    test('$platform uses the native layout without an Android call', () async {
      debugDefaultTargetPlatformOverride = platform;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            DeviceEnvironment.channel,
            (_) async => throw StateError('must not call'),
          );
      expect((await DeviceEnvironment.load()).isTelevision, isFalse);
    });
  }

  test('older native build fails safely without TV detection', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          DeviceEnvironment.channel,
          (_) async => throw MissingPluginException(),
        );
    expect((await DeviceEnvironment.load()).isTelevision, isFalse);
  });
}
