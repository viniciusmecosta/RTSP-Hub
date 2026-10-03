import 'dart:async';

import 'package:flutter/material.dart';
import '../shared/infrastructure/single_instance/single_instance_guard.dart';

import 'state/app_store.dart';
import '../shared/design_system/app_theme.dart';
import 'app_shell.dart';

class RtspViewApp extends StatefulWidget {
  const RtspViewApp({
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
  State<RtspViewApp> createState() => _RtspViewAppState();
}

class _RtspViewAppState extends State<RtspViewApp> {
  late final AppStore _store;

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
    return AnimatedBuilder(
      animation: _store,
      builder: (context, child) => AppScope(
        store: _store,
        child: MaterialApp(
          title: 'RTSP View',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: _store.themeMode,
          home: AppShell(
            forceConfiguration: widget.forceConfiguration,
            desktopWindowManager: widget.desktopWindowManager,
          ),
        ),
      ),
    );
  }
}

class MyApp extends RtspViewApp {
  const MyApp({super.store, super.key});
}
