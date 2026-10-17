import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../app/state/app_store.dart';
import '../../monitor/application/rtsp_session.dart';
import '../../monitor/presentation/camera_loading_view.dart';
import '../domain/camera_device.dart';

class CameraPreviewCapture {
  const CameraPreviewCapture(this.bytes, this.capturedAt);
  final Uint8List bytes;
  final DateTime capturedAt;
}

class CameraPreviewDialog extends StatefulWidget {
  const CameraPreviewDialog({
    required this.camera,
    required this.password,
    required this.defaultPort,
    required this.bufferMs,
    this.captureOnly = false,
    this.session,
    super.key,
  });

  final CameraDevice camera;
  final String? password;
  final int defaultPort;
  final int bufferMs;
  final bool captureOnly;
  final RtspSession? session;

  static Future<void> openSaved(
    BuildContext context,
    AppStore store,
    CameraDevice camera,
  ) async {
    final password = await store.passwordFor(camera);
    if (!context.mounted) return;
    final capture = await showDialog<CameraPreviewCapture>(
      context: context,
      builder: (_) => CameraPreviewDialog(
        camera: store.resolveCamera(camera),
        password: password,
        defaultPort: store.config.defaultPort,
        bufferMs: store.config.bufferMs,
      ),
    );
    if (capture != null) {
      final saved = await store.updateCameraSnapshot(
        camera.id,
        capture.bytes,
        capturedAt: capture.capturedAt,
      );
      if (!saved && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'O vídeo abriu, mas não foi possível salvar a miniatura.',
            ),
          ),
        );
      }
    }
  }

  @override
  State<CameraPreviewDialog> createState() => _CameraPreviewDialogState();
}

class _CameraPreviewDialogState extends State<CameraPreviewDialog>
    with WidgetsBindingObserver {
  late final RtspSession _session;
  Uint8List? _snapshot;
  DateTime? _capturedAt;
  bool _capturing = false;
  bool _closing = false;
  Timer? _deadline;
  String? _captureError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _session =
        widget.session ??
        RtspSession(
          camera: widget.camera,
          password: widget.password,
          defaultPort: widget.defaultPort,
          bufferMs: widget.bufferMs,
          useMainStream: true,
          retryEnabled: false,
        );
    _session.addListener(_refresh);
    _session.status.addListener(_refresh);
    _session.firstFrameRendered.addListener(_capture);
    if (widget.captureOnly) {
      _deadline = Timer(const Duration(seconds: 12), _close);
    }
    unawaited(_session.start());
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _capture() async {
    if (!_session.firstFrameRendered.value || _capturing || _snapshot != null) {
      return;
    }
    _capturing = true;
    try {
      final bytes = await _session.player?.screenshot().timeout(
        const Duration(seconds: 3),
      );
      if (bytes == null || !mounted) return;
      final capturedAt = DateTime.now().toUtc();
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 640,
        allowUpscaling: false,
      );
      try {
        final frame = await codec.getNextFrame();
        try {
          final data = await frame.image.toByteData(
            format: ui.ImageByteFormat.png,
          );
          if (mounted && data != null) {
            setState(() {
              _snapshot = data.buffer.asUint8List();
              _capturedAt = capturedAt;
            });
          }
        } finally {
          frame.image.dispose();
        }
      } finally {
        codec.dispose();
      }
    } on Object {
      if (mounted) {
        setState(
          () => _captureError =
              'Vídeo disponível. Não foi possível capturar a miniatura.',
        );
      }
    } finally {
      _capturing = false;
      if (widget.captureOnly && mounted) _close();
    }
  }

  void _close() {
    if (!mounted || _closing) return;
    _closing = true;
    _deadline?.cancel();
    Navigator.pop(
      context,
      _snapshot == null ? null : CameraPreviewCapture(_snapshot!, _capturedAt!),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      unawaited(_session.pause());
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_session.start());
    }
  }

  @override
  void dispose() {
    _deadline?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _session.removeListener(_refresh);
    _session.status.removeListener(_refresh);
    _session.firstFrameRendered.removeListener(_capture);
    unawaited(_session.disposeSession());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _session.videoController;
    return PopScope<Uint8List>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _close();
      },
      child: Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.camera.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      onPressed: _close,
                      tooltip: 'Fechar vídeo',
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        const ColoredBox(color: Colors.black),
                        if (controller != null)
                          Video(
                            controller: controller,
                            controls: NoVideoControls,
                          ),
                        if (!_session.firstFrameRendered.value)
                          CameraLoadingView(
                            status: _session.status.value,
                            error: _session.error.value,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _captureError ??
                      (_snapshot == null
                          ? 'Aguardando vídeo para capturar a miniatura.'
                          : 'Miniatura capturada • ${_session.currentResolution ?? 'Vídeo ao vivo'}'),
                ),
                if (_session.error.value != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _session.error.value!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (_session.status.value == CameraPlaybackStatus.error &&
                        !widget.captureOnly)
                      OutlinedButton.icon(
                        onPressed: () => _session.start(),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Tentar novamente'),
                      ),
                    FilledButton(
                      onPressed: _close,
                      child: Text(
                        widget.captureOnly ? 'Salvar sem esperar' : 'Concluir',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
