import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../shared/infrastructure/single_instance/single_instance_guard.dart';

import 'state/app_store.dart';
import '../shared/design_system/app_theme.dart';
import '../shared/platform/device_environment.dart';
import 'app_shell.dart';

class RtspHubApp extends StatefulWidget {
  const RtspHubApp({
    this.forceConfiguration = false,
    this.desktopWindowManager = false,
    this.instanceGuard,
    this.store,
    this.deviceEnvironment = const DeviceEnvironment(),
    super.key,
  });

  final bool forceConfiguration;
  final bool desktopWindowManager;
  final SingleInstanceGuard? instanceGuard;
  final AppStore? store;
  final DeviceEnvironment deviceEnvironment;

  @override
  State<RtspHubApp> createState() => _RtspHubAppState();
}

typedef RtspViewApp = RtspHubApp;

class _RtspHubAppState extends State<RtspHubApp> {
  late final AppStore _store;
  late final ThemeData _lightTheme = widget.deviceEnvironment.isTelevision
      ? AppTheme.forTelevision(AppTheme.light)
      : AppTheme.light;
  late final ThemeData _darkTheme = widget.deviceEnvironment.isTelevision
      ? AppTheme.forTelevision(AppTheme.dark)
      : AppTheme.dark;

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? AppStore();
    _store.load();
  }

  @override
  void dispose() {
    _store.dispose();
    unawaited(widget.instanceGuard?.release() ?? Future<void>.value());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DeviceEnvironmentScope(
      environment: widget.deviceEnvironment,
      child: AppScope(
        store: _store,
        child: ValueListenableBuilder<ThemeMode>(
          valueListenable: _store.themeModeListenable,
          builder: (context, themeMode, _) => MaterialApp(
            title: 'RTSP Hub',
            debugShowCheckedModeBanner: false,
            theme: _lightTheme,
            darkTheme: _darkTheme,
            themeMode: themeMode,
            builder: (context, child) => Shortcuts(
              shortcuts: const {
                SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
                SingleActivator(LogicalKeyboardKey.gameButtonA):
                    ActivateIntent(),
              },
              child: FocusTraversalGroup(
                policy: ReadingOrderTraversalPolicy(),
                child: child ?? const SizedBox.shrink(),
              ),
            ),
            home: AppShell(
              forceConfiguration: widget.forceConfiguration,
              desktopWindowManager: widget.desktopWindowManager,
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends RtspHubApp {
  const MyApp({super.store, super.deviceEnvironment, super.key});
}
