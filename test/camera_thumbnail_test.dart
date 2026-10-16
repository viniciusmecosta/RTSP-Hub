import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rtsp_hub/app/state/app_store.dart';
import 'package:rtsp_hub/features/camera_catalog/data/camera_snapshot_store.dart';
import 'package:rtsp_hub/features/camera_catalog/presentation/camera_thumbnail.dart';

class _TrackingSnapshots extends CameraSnapshotStore {
  _TrackingSnapshots({required super.directory});

  final reads = <String, int>{};

  @override
  Future<File> fileFor(String id) {
    reads.update(id, (value) => value + 1, ifAbsent: () => 1);
    return super.fileFor(id);
  }
}

void main() {
  testWidgets(
    'atualizar uma miniatura preserva as outras sem releitura do disco',
    (tester) async {
      final directory = Directory.systemTemp.createTempSync('thumbnail-test');
      final snapshots = _TrackingSnapshots(directory: directory);
      final store = AppStore(snapshotStore: snapshots);
      await tester.runAsync(() => snapshots.fileFor('initial'));
      addTearDown(() {
        store.dispose();
        snapshots.dispose();
        directory.deleteSync(recursive: true);
      });
      await tester.pumpWidget(
        AppScope(
          store: store,
          child: const MaterialApp(
            home: Scaffold(
              body: Row(
                children: [
                  SizedBox(
                    width: 100,
                    height: 100,
                    child: CameraThumbnail(cameraId: 'a'),
                  ),
                  SizedBox(
                    width: 100,
                    height: 100,
                    child: CameraThumbnail(cameraId: 'b'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      snapshots.reads.clear();
      await tester.runAsync(
        () => snapshots.save(
          'a',
          base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jZ9kAAAAASUVORK5CYII=',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(snapshots.reads['a'], greaterThan(0));
      expect(snapshots.reads['b'], isNull);
      expect(tester.takeException(), isNull);
    },
  );
}
