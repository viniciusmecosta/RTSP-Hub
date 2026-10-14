import 'dart:io';

import 'package:flutter/material.dart';

import '../../../app/state/app_store.dart';
import '../data/camera_snapshot_store.dart';

class CameraThumbnail extends StatefulWidget {
  const CameraThumbnail({required this.cameraId, super.key});

  final String cameraId;

  @override
  State<CameraThumbnail> createState() => _CameraThumbnailState();
}

class _CameraThumbnailState extends State<CameraThumbnail> {
  CameraSnapshotStore? _store;
  Future<File?>? _file;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = AppScope.of(context).snapshots;
    if (identical(store, _store)) return;
    _store?.removeListener(_reload);
    _store = store..addListener(_reload);
    _file = _read();
  }

  @override
  void didUpdateWidget(CameraThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cameraId != widget.cameraId) _file = _read();
  }

  Future<File?> _read() async {
    try {
      final file = await _store!.fileFor(widget.cameraId);
      return await file.exists() ? file : null;
    } on Object {
      return null;
    }
  }

  void _reload() {
    if (mounted) setState(() => _file = _read());
  }

  @override
  void dispose() {
    _store?.removeListener(_reload);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final placeholder = ColoredBox(
      color: colors.surfaceContainerHighest,
      child: Center(
        child: Icon(Icons.videocam_outlined, color: colors.onSurfaceVariant),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: FutureBuilder<File?>(
        future: _file,
        builder: (context, snapshot) {
          final file = snapshot.data;
          if (file == null) return placeholder;
          return Image(
            key: ValueKey(_store!.revision),
            image: ResizeImage(FileImage(file), width: 640),
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            excludeFromSemantics: true,
            errorBuilder: (_, error, stack) => placeholder,
          );
        },
      ),
    );
  }
}
