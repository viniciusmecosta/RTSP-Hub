import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class DeviceEnvironment {
  const DeviceEnvironment({this.isTelevision = false});

  static const channel = MethodChannel('com.rtsp.rtsp_hub/device');
  final bool isTelevision;

  static Future<DeviceEnvironment> load() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const DeviceEnvironment();
    }
    try {
      final television = await channel
          .invokeMethod<bool>('isTelevision')
          .timeout(const Duration(seconds: 1));
      return DeviceEnvironment(isTelevision: television == true);
    } on Object {
      return const DeviceEnvironment();
    }
  }
}

class DeviceEnvironmentScope extends InheritedWidget {
  const DeviceEnvironmentScope({
    required this.environment,
    required super.child,
    super.key,
  });

  final DeviceEnvironment environment;

  static DeviceEnvironment of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<DeviceEnvironmentScope>()
          ?.environment ??
      const DeviceEnvironment();

  @override
  bool updateShouldNotify(DeviceEnvironmentScope oldWidget) =>
      environment.isTelevision != oldWidget.environment.isTelevision;
}
