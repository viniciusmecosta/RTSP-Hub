import 'package:flutter/material.dart';

import '../shared/design_system/app_theme.dart';
import 'app_shell.dart';

class RtspViewApp extends StatelessWidget {
  const RtspViewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RTSP View',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const AppShell(),
    );
  }
}

class MyApp extends RtspViewApp {
  const MyApp({super.key});
}
