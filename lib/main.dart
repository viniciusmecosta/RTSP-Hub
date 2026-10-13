import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

import 'app/app.dart';
import 'shared/infrastructure/single_instance/single_instance_guard.dart';

export 'app/app.dart' show MyApp;

Future<void> main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  final desktop =
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
  SingleInstanceGuard? guard;
  if (desktop) {
    final supportDirFuture = getApplicationSupportDirectory();
    final windowInitFuture = windowManager.ensureInitialized();
    try {
      guard = await SingleInstanceGuard.acquire(
        baseDirectory: await supportDirFuture,
      );
    } on Object {
      runApp(
        const _StartupNoticeApp(
          message:
              'Não foi possível reservar o acesso exclusivo. Confira as permissões da pasta de dados do RTSP View.',
        ),
      );
      return;
    }
    if (guard == null) {
      runApp(
        const _StartupNoticeApp(
          message: 'O RTSP View já está aberto nesta sessão.',
        ),
      );
      return;
    }
    await windowInitFuture;
    unawaited(
      windowManager.waitUntilReadyToShow(
        const WindowOptions(
          size: Size(1280, 800),
          minimumSize: Size(640, 480),
          center: true,
          title: 'RTSP View',
        ),
        () async {
          await windowManager.show();
          await windowManager.focus();
        },
      ),
    );
  }
  runApp(
    RtspViewApp(
      forceConfiguration:
          arguments.contains('--config') || arguments.contains('-c'),
      desktopWindowManager: desktop,
      instanceGuard: guard,
    ),
  );
}

class _StartupNoticeApp extends StatelessWidget {
  const _StartupNoticeApp({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'RTSP View',
    home: Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline, size: 42),
              const SizedBox(height: 12),
              Text(message),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => exit(0),
                child: const Text('Fechar'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
