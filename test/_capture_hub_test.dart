import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rtsp_hub/app/data/app_configuration.dart';
import 'package:rtsp_hub/app/state/app_store.dart';
import 'package:rtsp_hub/main.dart';
import 'package:rtsp_hub/features/camera_catalog/domain/camera_device.dart';
import 'global_connection_backup_test.dart' show MemoryRepository, MemoryCredentials;

void main() {
  testWidgets('capture design review', (tester) async {
    tester.view.devicePixelRatio = 1;
    await tester.runAsync(() async {
      final font = await File('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf').readAsBytes();
      await ui.loadFontFromList(font, fontFamily: 'Roboto');
      await ui.loadFontFromList(await File('/home/vini/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf').readAsBytes(), fontFamily: 'MaterialIcons');
      await ui.loadFontFromList(await File('/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf').readAsBytes(), fontFamily: 'monospace');
    });
    for (final section in ['dashboard', 'cameras', 'settings', 'global']) {
      tester.view.physicalSize = const Size(1440, 1000);
      final repository = MemoryRepository()..value = AppConfiguration(
        startupSection: section == 'global' ? 'dashboard' : section, tutorialCompleted: true, themeMode: 'dark',
        cameras: List.generate(4, (index) => CameraDevice(id: 'cam$index', name: ['Portaria', 'Garagem', 'Recepção', 'Entrada lateral'][index], host: '192.168.1.${10 + index}', mainPath: '/live')),
        slotCameraIds: const ['cam0', 'cam1', 'cam2', 'cam3'],
      );
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(key: key, child: MyApp(store: AppStore(repository: repository, credentials: MemoryCredentials()))));
      await tester.pumpAndSettle();
      if (section == 'global') { await tester.tap(find.text('Conexão global')); await tester.pumpAndSettle(); }
      await tester.runAsync(() async { await precacheImage(const AssetImage('assets/logo.png'), key.currentContext!); });
      await tester.pump();
      await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('/tmp/hub-$section.png').writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await tester.pumpWidget(const SizedBox());
    }
  });
}
