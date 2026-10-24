import 'package:flutter_test/flutter_test.dart';
import 'package:rtsp_hub/app/data/app_configuration.dart';
import 'package:rtsp_hub/app/state/app_store.dart';
import 'package:rtsp_hub/features/monitor/domain/monitor_paging_policy.dart';
import 'package:rtsp_hub/features/monitor/domain/stream_selection_policy.dart';

import 'global_connection_backup_test.dart'
    show MemoryRepository, MemoryCredentials;

void main() {
  test('automatic preserves the full native grid and pages TVs by four', () {
    expect(
      MonitorPagingPolicy.pageSize(
        cameraCount: 16,
        preference: 0,
        television: false,
      ),
      16,
    );
    expect(
      MonitorPagingPolicy.pageSize(
        cameraCount: 16,
        preference: 0,
        television: true,
      ),
      4,
    );
  });
  test('manual paging and unlimited mode work on every form factor', () {
    for (final television in [false, true]) {
      expect(
        MonitorPagingPolicy.pageSize(
          cameraCount: 32,
          preference: -1,
          television: television,
        ),
        32,
      );
      expect(
        MonitorPagingPolicy.pageSize(
          cameraCount: 16,
          preference: 2,
          television: television,
        ),
        2,
      );
      expect(
        MonitorPagingPolicy.pageSize(
          cameraCount: 2,
          preference: 16,
          television: television,
        ),
        2,
      );
      expect(
        MonitorPagingPolicy.pageSize(
          cameraCount: 0,
          preference: 0,
          television: television,
        ),
        1,
      );
    }
  });
  test(
    'page preference survives serialization and invalid input normalizes',
    () {
      for (final size in MonitorPagingPolicy.choices) {
        final config = AppConfiguration(monitorPageSize: size);
        expect(
          AppConfiguration.fromJson(config.toJson()).monitorPageSize,
          size,
        );
      }
      expect(
        AppConfiguration.fromJson({
          'settings': {'monitorPageSize': 999},
        }).monitorPageSize,
        0,
      );
      expect(AppConfiguration.fromJson({}).monitorPageSize, 0);
    },
  );
  test('settings save page size and reject invalid values', () async {
    final store = AppStore(
      repository: MemoryRepository(),
      credentials: MemoryCredentials(),
    );
    addTearDown(store.dispose);
    await store.load();
    await store.updateSettings(monitorPageSize: 2);
    expect(store.config.monitorPageSize, 2);
    await store.updateSettings(monitorPageSize: 3);
    expect(store.config.monitorPageSize, 2);
    expect(store.message, contains('quantidade válida'));
    await store.updateSettings(monitorPageSize: -1);
    expect(store.config.monitorPageSize, -1);
  });
  test(
    'large catalogs retain pages beyond the previous hundred-page ceiling',
    () {
      final config = AppConfiguration(
        slotCameraIds: List.generate(240, (i) => 'cam-$i'),
        lastMonitorPage: 220,
        monitorPageSize: 1,
      );
      final restored = AppConfiguration.fromJson(config.toJson());
      expect(restored.lastMonitorPage, 220);
      expect(restored.monitorPageSize, 1);
    },
  );
  test('page size is preserved by full backup and restore', () async {
    final store = AppStore(
      repository: MemoryRepository(),
      credentials: MemoryCredentials(),
    );
    final clone = AppStore(
      repository: MemoryRepository(),
      credentials: MemoryCredentials(),
    );
    addTearDown(store.dispose);
    addTearDown(clone.dispose);
    await store.load();
    await clone.load();
    await store.updateSettings(monitorPageSize: 2);
    final backup = await store.exportBackup();
    expect(await clone.importConfiguration(backup), isTrue);
    expect(clone.config.monitorPageSize, 2);
  });
  test('TV focus preserves economy and manual quality is still available', () {
    expect(
      StreamSelectionPolicy.useMainStream(
        resourceMode: 'light',
        focused: true,
        upgradeFocusedStream: false,
      ),
      isFalse,
    );
    expect(
      StreamSelectionPolicy.useMainStream(
        resourceMode: 'light',
        focused: true,
        upgradeFocusedStream: false,
        manualChoice: true,
      ),
      isTrue,
    );
    expect(
      StreamSelectionPolicy.useMainStream(
        resourceMode: 'quality',
        upgradeFocusedStream: false,
      ),
      isTrue,
    );
    expect(
      StreamSelectionPolicy.useMainStream(resourceMode: 'light', focused: true),
      isTrue,
    );
    expect(
      StreamSelectionPolicy.useMainStream(
        resourceMode: 'light',
        upgradeFocusedStream: false,
        hasSubStream: false,
      ),
      isTrue,
    );
  });
}
