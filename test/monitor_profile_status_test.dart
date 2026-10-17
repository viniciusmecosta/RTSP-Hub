import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rtsp_hub/app/state/app_store.dart';
import 'package:rtsp_hub/features/layouts/presentation/widgets/monitor_profile_status.dart';

import 'global_connection_backup_test.dart'
    show MemoryRepository, MemoryCredentials;

void main() {
  testWidgets('updates the active profile from its modified indicator', (
    tester,
  ) async {
    final store = AppStore(
      repository: MemoryRepository(),
      credentials: MemoryCredentials(),
    );
    addTearDown(store.dispose);
    await store.load();
    await store.saveMonitorProfile(name: 'Portaria');
    await store.setLayout('GRID_2H');
    await tester.pumpWidget(
      AppScope(
        store: store,
        child: const MaterialApp(home: Scaffold(body: MonitorProfileStatus())),
      ),
    );
    expect(find.text('Portaria · Modificado'), findsOneWidget);
    await tester.tap(find.text('Salvar alterações'));
    await tester.pumpAndSettle();
    expect(find.text('Portaria · Salvo'), findsOneWidget);
    expect(store.config.monitorProfiles, hasLength(1));
    expect(store.activeMonitorProfile!.layoutId, 'GRID_2H');
  });
}
