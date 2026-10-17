import 'dart:io';

import 'package:flutter/material.dart';

import '../../../app/state/app_store.dart';
import '../data/camera_snapshot_store.dart';
import 'saved_frame_label.dart';

class CameraThumbnail extends StatefulWidget {
  const CameraThumbnail({
    required this.cameraId,
    this.showCaptureDate = false,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    super.key,
  });

  final String cameraId;
  final bool showCaptureDate;
  final BorderRadius borderRadius;

  @override
  State<CameraThumbnail> createState() => _CameraThumbnailState();
}

class _CameraThumbnailState extends State<CameraThumbnail> {
  CameraSnapshotStore? _store;
  Future<File?>? _file;
  int _imageRevision = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = AppScope.of(context).snapshots;
    if (identical(store, _store)) return;
    _store?.removeListener(_reload);
    _store = store..addListener(_reload);
    _imageRevision = store.revision;
    _file = _read();
  }

  @override
  void didUpdateWidget(CameraThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cameraId != widget.cameraId) {
      _imageRevision = _store?.revision ?? 0;
      _file = _read();
    }
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
    if (mounted && _store?.lastChangedId == widget.cameraId) {
      setState(() {
        _imageRevision = _store!.revision;
        _file = _read();
      });
    }
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
      borderRadius: widget.borderRadius,
      child: FutureBuilder<File?>(
        future: _file,
        builder: (context, snapshot) {
          final file = snapshot.data;
          if (file == null) return placeholder;
          final capturedAt = AppScope.of(context).cameras
              .where((c) => c.id == widget.cameraId)
              .firstOrNull
              ?.thumbnailCapturedAt;
          final label = savedFrameLabel(capturedAt);
          return Tooltip(
            message: label,
            child: Semantics(
              label: label,
              image: true,
              child: LayoutBuilder(
                builder: (context, constraints) => Stack(
                  fit: StackFit.expand,
                  children: [
                    Image(
                      key: ValueKey((widget.cameraId, _imageRevision)),
                      image: ResizeImage(
                        FileImage(file),
                        width: CameraSnapshotStore.decodeWidth(
                          constraints.maxWidth *
                              MediaQuery.devicePixelRatioOf(context),
                        ),
                      ),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      excludeFromSemantics: true,
                      errorBuilder: (_, error, stack) => placeholder,
                    ),
                    if (widget.showCaptureDate &&
                        constraints.maxWidth >= 140 &&
                        constraints.maxHeight >= 70)
                      Positioned(
                        left: 6,
                        right: 6,
                        bottom: 6,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 4,
                            ),
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
