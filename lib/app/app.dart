import 'dart:async';

import 'package:flutter/material.dart';
import '../shared/infrastructure/single_instance/single_instance_guard.dart';

import 'state/app_store.dart';
import '../shared/design_system/app_theme.dart';
import 'app_shell.dart';

class RtspHubApp extends StatefulWidget {
  const RtspHubApp({
    this.forceConfiguration = false,
    this.desktopWindowManager = false,
    this.instanceGuard,
    this.store,
    super.key,
  });

  final bool forceConfiguration;
  final bool desktopWindowManager;
  final SingleInstanceGuard? instanceGuard;
  final AppStore? store;

  @override
  State<RtspHubApp> createState() => _RtspHubAppState();
}

typedef RtspViewApp = RtspHubApp;

class _RtspHubAppState extends State<RtspHubApp> {
  late final AppStore _store;
  late final ThemeData _lightTheme = AppTheme.light;
  late final ThemeData _darkTheme = AppTheme.dark;

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
    return AppScope(
      store: _store,
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: _store.themeModeListenable,
        builder: (context, themeMode, _) => MaterialApp(
          title: 'RTSP Hub',
          debugShowCheckedModeBanner: false,
          theme: _lightTheme,
          darkTheme: _darkTheme,
          themeMode: themeMode,
          home: AppShell(
            forceConfiguration: widget.forceConfiguration,
            desktopWindowManager: widget.desktopWindowManager,
          ),
        ),
      ),
    );
  }
}

class MyApp extends RtspHubApp {
  const MyApp({super.store, super.key});
}
