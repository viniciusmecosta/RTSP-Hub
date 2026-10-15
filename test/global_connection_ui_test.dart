import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rtsp_hub/app/state/app_store.dart';
import 'package:rtsp_hub/features/camera_catalog/presentation/camera_catalog_page.dart';
import 'package:rtsp_hub/features/settings/presentation/global_connection_page.dart';
import 'package:rtsp_hub/shared/design_system/app_theme.dart';

import 'global_connection_backup_test.dart'
    show MemoryRepository, MemoryCredentials;

void main() {
  for (final size in [
    const Size(375, 812),
    const Size(768, 1024),
    const Size(1440, 900),
  ]) {
    testWidgets(
      'global configuration validates and saves independently at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final store = AppStore(
          repository: MemoryRepository(),
          credentials: MemoryCredentials(),
        );
        addTearDown(store.dispose);
        await store.load();
        await tester.pumpWidget(
          AppScope(
            store: store,
            child: MaterialApp(
              theme: AppTheme.light,
              home: const GlobalConnectionPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Buscar câmeras'), findsNothing);
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Usuário global'),
          'operator',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Senha global'),
          'p@ss: ç#',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Porta padrão'),
          '70000',
        );
        await tester.ensureVisible(find.text('Salvar conexão global'));
        await tester.tap(find.text('Salvar conexão global'));
        await tester.pumpAndSettle();
        expect(store.config.defaultUser, 'admin');
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Porta padrão'),
          '8554',
        );
        await tester.ensureVisible(find.text('Salvar conexão global'));
        await tester.tap(find.text('Salvar conexão global'));
        await tester.pumpAndSettle();
        expect(store.config.defaultPort, 8554);
        expect(store.config.defaultUser, 'operator');
        expect(await store.networkDiscoveryPassword(), 'p@ss: ç#');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'camera editor pre-fills global port and leaves overrides independent',
    (tester) async {
      final store = AppStore(
        repository: MemoryRepository(),
        credentials: MemoryCredentials(),
      );
      addTearDown(store.dispose);
      await store.load();
      await store.saveGlobalConnection(
        username: 'operator',
        password: 'global',
        port: '8554',
        mainPath: '/global',
      );
      await tester.pumpWidget(
        AppScope(
          store: store,
          child: MaterialApp(
            theme: AppTheme.dark,
            home: const Scaffold(body: CameraCatalogPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Adicionar câmera').first);
      await tester.pumpAndSettle();
      final port = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Porta'),
      );
      expect(port.controller!.text, '8554');
      final user = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Usuário específico'),
      );
      expect(user.controller!.text, isEmpty);
      expect(user.enabled, isNot(false));
      expect(find.text('Usar credenciais globais'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
