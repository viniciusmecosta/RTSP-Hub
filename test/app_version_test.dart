import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:rtsp_hub/app/state/app_store.dart';
import 'package:rtsp_hub/features/settings/presentation/settings_page.dart';

import 'global_connection_backup_test.dart'
    show MemoryRepository, MemoryCredentials;

void main() {
  testWidgets(
    'settings reports the version and build embedded in the installed app',
    (tester) async {
      PackageInfo.setMockInitialValues(
        appName: 'RTSP Hub',
        packageName: 'com.rtsp.rtsp_view',
        version: '0.0.4',
        buildNumber: '27',
        buildSignature: '',
      );
      final store = AppStore(
        repository: MemoryRepository(),
        credentials: MemoryCredentials(),
      );
      addTearDown(store.dispose);
      await store.load();
      await tester.pumpWidget(
        AppScope(
          store: store,
          child: const MaterialApp(home: Scaffold(body: SettingsPage())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Versão 0.0.4 · compilação 27'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
