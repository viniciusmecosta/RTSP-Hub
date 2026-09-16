import 'package:flutter/material.dart';

import 'state/app_store.dart';
import '../shared/design_system/app_theme.dart';
import 'app_shell.dart';

class RtspViewApp extends StatefulWidget {
  const RtspViewApp({super.key});

  @override
  State<RtspViewApp> createState() => _RtspViewAppState();
}

class _RtspViewAppState extends State<RtspViewApp> {
  late final AppStore _store;

  @override
  void initState() {
    super.initState();
    _store = AppStore();
    _store.load();
  }

  @override
  void dispose() {
    _store.dispose();
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
          home: const AppShell(),
        ),
      ),
    );
  }
}

class MyApp extends RtspViewApp {
  const MyApp({super.key});
}
