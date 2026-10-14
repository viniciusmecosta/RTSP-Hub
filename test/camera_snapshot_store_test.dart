import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rtsp_view/features/camera_catalog/data/camera_snapshot_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('decodes only the thumbnail size needed for the display', () {
    expect(CameraSnapshotStore.decodeWidth(72), 160);
    expect(CameraSnapshotStore.decodeWidth(220), 320);
    expect(CameraSnapshotStore.decodeWidth(500), 640);
    expect(CameraSnapshotStore.decodeWidth(2000), 640);
  });

  test(
    'stores snapshots separately and confines filenames to its directory',
    () async {
      final directory = await Directory.systemTemp.createTemp('snapshots-test');
      addTearDown(() => directory.delete(recursive: true));
      final store = CameraSnapshotStore(directory: directory);
      addTearDown(store.dispose);
      var changes = 0;
      store.addListener(() => changes++);
      final bytes = Uint8List.fromList([1, 2, 3]);
      expect(await store.save('../../camera', bytes), isTrue);
      final file = await store.fileFor('../../camera');
      expect(file.parent.path, directory.path);
      expect(await file.readAsBytes(), bytes);
      expect(changes, 1);
      expect(await store.save('../../camera', Uint8List.fromList([4])), isTrue);
      expect(await file.readAsBytes(), [4]);
      await store.remove('../../camera');
      expect(await file.exists(), isFalse);
      expect(changes, 3);
    },
  );

  test('rejects empty and excessive snapshots without writing', () async {
    final directory = await Directory.systemTemp.createTemp('snapshots-test');
    addTearDown(() => directory.delete(recursive: true));
    final store = CameraSnapshotStore(directory: directory);
    addTearDown(store.dispose);
    expect(await store.save('a', Uint8List(0)), isFalse);
    expect(await store.save('a', Uint8List(4 * 1024 * 1024 + 1)), isFalse);
    expect(await directory.list().toList(), isEmpty);
  });
}
