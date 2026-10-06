import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../app/state/app_store.dart';
import '../../../features/camera_catalog/domain/camera_device.dart';
import '../../../features/layouts/domain/layout_preset.dart';
import '../../../features/layouts/domain/layout_geometry.dart';
import '../application/rtsp_session.dart';

class MonitorPage extends StatefulWidget {
  const MonitorPage({
    required this.onExit,
    required this.onConfigure,
    super.key,
  });

  final VoidCallback onExit;
  final VoidCallback onConfigure;

  @override
  State<MonitorPage> createState() => _MonitorPageState();
}

class _MonitorPageState extends State<MonitorPage> {
  final Map<String, RtspSession> _sessions = {};
  Timer? _controlsTimer;
  int _page = 0;
  bool _mainStreams = false;
  bool _showControls = true;
  bool _showDiagnostics = false;
  String? _focusedCameraId;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _scheduleControlsHide();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncSessions();
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    for (final session in _sessions.values) {
      unawaited(session.disposeSession());
    }
    _sessions.clear();
    super.dispose();
  }

  Future<void> _syncSessions() async {
    final generation = ++_generation;
    final store = AppScope.of(context);
    final ids = store.config.slotCameraIds;
    final pageSize = _pageSize(
      store.activeLayout,
      MediaQuery.sizeOf(context).width,
    );
    final pages = ((ids.length + pageSize - 1) ~/ pageSize).clamp(1, 100);
    _page = _page.clamp(0, pages - 1);
    if (_focusedCameraId != null && !ids.contains(_focusedCameraId)) {
      _focusedCameraId = null;
    }
    final start = _page * pageSize;
    final end = (start + pageSize).clamp(0, ids.length);
    final pageSlots = ids.sublist(start, end);
    final visibleIds =
        (_focusedCameraId == null ? pageSlots : <String?>[_focusedCameraId])
            .whereType<String>()
            .toSet();
    final staleSessions = <RtspSession>[];
    for (final id in _sessions.keys.toList()) {
      if (!visibleIds.contains(id)) {
        final old = _sessions.remove(id);
        if (old != null) staleSessions.add(old);
      }
    }
    await Future.wait(staleSessions.map((session) => session.disposeSession()));
    if (!mounted || generation != _generation) return;
    for (var index = start; index < end; index++) {
      final id = ids[index];
      if (id == null) continue;
      if (_focusedCameraId != null && id != _focusedCameraId) continue;
      final camera = store.cameras.where((item) => item.id == id).firstOrNull;
      if (camera == null) continue;
      final existing = _sessions[id];
      final mainStream =
          _mainStreams ||
          store.config.resourceMode == 'quality' ||
          camera.subPath.isEmpty;
      if (existing != null &&
          identical(existing.camera, camera) &&
          existing.bufferMs == store.config.bufferMs &&
          existing.useMainStream == mainStream) {
        continue;
      }
      if (existing != null) {
        _sessions.remove(id);
        unawaited(existing.disposeSession());
      }
      final secret = await store.passwordFor(camera);
      if (!mounted || generation != _generation) return;
      final session = RtspSession(
        camera: camera,
        password: secret,
        defaultPort: store.config.defaultPort,
        bufferMs: store.config.bufferMs,
        useMainStream: mainStream,
      );
      _sessions[id] = session;
      unawaited(session.start());
      if (index < ids.length - 1) {
        await Future<void>.delayed(const Duration(milliseconds: 180));
      }
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final layout = store.activeLayout;
    final slots = store.config.slotCameraIds;
    final perPage = _pageSize(layout, MediaQuery.sizeOf(context).width);
    final pages = ((slots.length + perPage - 1) ~/ perPage).clamp(1, 100);
    if (_page >= pages) _page = pages - 1;
    final focusedIndex = _focusedCameraId == null
        ? -1
        : slots.indexOf(_focusedCameraId!);
    final from = focusedIndex >= 0 ? focusedIndex : _page * perPage;
    final visibleCount = focusedIndex >= 0
        ? 1
        : (slots.length - from).clamp(0, perPage);
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleBack();
      },
      child: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.escape) {
              _handleBack();
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.f3) {
              setState(() => _showDiagnostics = !_showDiagnostics);
              if (!_showDiagnostics) _scheduleControlsHide();
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.f2) {
              widget.onConfigure();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: MouseRegion(
          cursor: _showControls
              ? SystemMouseCursors.basic
              : SystemMouseCursors.none,
          onHover: (_) => _revealControls(),
          child: Scaffold(
            backgroundColor: const Color(0xFF06090F),
            body: SafeArea(
              child: Column(
                children: [
                  if (_showControls) _toolbar(context, store, layout, pages),
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Positioned.fill(
                          child: store.cameras.isEmpty
                              ? const _MonitorEmpty(
                                  message:
                                      'Cadastre câmeras para começar a visualizar.',
                                )
                              : visibleCount == 0
                              ? const _MonitorEmpty(
                                  message:
                                      'A grade está vazia. Associe câmeras em Layouts.',
                                )
                              : LayoutBuilder(
                                  builder: (context, constraints) {
                                    final columns = _columns(
                                      layout,
                                      constraints.maxWidth,
                                    );
                                    final rows = (visibleCount / columns)
                                        .ceil();
                                    if (layout.focusIndex != null &&
                                        constraints.maxWidth >= 600 &&
                                        focusedIndex < 0 &&
                                        from == 0 &&
                                        visibleCount == layout.cameraCount) {
                                      final rectangles = LayoutGeometry.tiles(
                                        layout.id,
                                        Size(
                                          constraints.maxWidth,
                                          constraints.maxHeight,
                                        ),
                                      );
                                      if (rectangles.length == visibleCount) {
                                        return Stack(
                                          children: [
                                            for (
                                              var offset = 0;
                                              offset < visibleCount;
                                              offset++
                                            )
                                              Positioned.fromRect(
                                                rect: rectangles[offset]
                                                    .deflate(1.5),
                                                child: _cameraTile(
                                                  store,
                                                  slots,
                                                  offset,
                                                ),
                                              ),
                                          ],
                                        );
                                      }
                                    }
                                    return GridView.builder(
                                      padding: const EdgeInsets.all(3),
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      itemCount: visibleCount,
                                      gridDelegate:
                                          SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: columns,
                                            mainAxisSpacing: 3,
                                            crossAxisSpacing: 3,
                                            childAspectRatio:
                                                constraints.maxWidth < 600
                                                ? 16 / 10
                                                : (constraints.maxWidth /
                                                          columns) /
                                                      ((constraints.maxHeight /
                                                              rows)
                                                          .clamp(
                                                            80,
                                                            double.infinity,
                                                          )),
                                          ),
                                      itemBuilder: (context, offset) =>
                                          _cameraTile(
                                            store,
                                            slots,
                                            from + offset,
                                          ),
                                    );
                                  },
                                ),
                        ),
                        if (_showDiagnostics)
                          Positioned(
                            top: 12,
                            right: 12,
                            child: _diagnostics(context, store, slots),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _cameraTile(AppStore store, List<String?> slots, int slotIndex) {
    final id = slots[slotIndex];
    final camera = id == null
        ? null
        : store.cameras.where((item) => item.id == id).firstOrNull;
    final session = id == null ? null : _sessions[id];
    return _CameraTile(
      camera: camera,
      session: session,
      onTap: _revealControls,
      onFocus: camera == null
          ? null
          : () {
              setState(() {
                _focusedCameraId = _focusedCameraId == camera.id
                    ? null
                    : camera.id;
              });
              _syncSessions();
            },
      onRetry: session == null ? null : () => session.start(),
    );
  }

  Widget _diagnostics(
    BuildContext context,
    AppStore store,
    List<String?> slots,
  ) {
    final width = MediaQuery.sizeOf(context).width;
    return SizedBox(
      width: width < 380 ? width - 24 : 340,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.65,
        ),
        child: Material(
          color: const Color(0xF0121924),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Diagnósticos da sessão',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Fechar diagnósticos',
                        onPressed: _closeDiagnostics,
                        icon: const Icon(Icons.close, color: Colors.white70),
                      ),
                    ],
                  ),
                  Text(
                    '${store.activeLayout.name} · buffer ${store.config.bufferMs} ms · ${store.config.resourceMode}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const Divider(color: Color(0xFF344153)),
                  for (var index = 0; index < slots.length; index++)
                    if (slots[index] case final String id)
                      _diagnosticCamera(store, id, index),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _diagnosticCamera(AppStore store, String id, int index) {
    final camera = store.cameras.where((item) => item.id == id).firstOrNull;
    final session = _sessions[id];
    if (camera == null) return const SizedBox.shrink();
    if (session == null) return _diagnosticRow(index, camera.name, 'Em espera');
    return ValueListenableBuilder<CameraPlaybackStatus>(
      valueListenable: session.status,
      builder: (context, status, _) =>
          _diagnosticRow(index, camera.name, switch (status) {
            CameraPlaybackStatus.idle => 'Aguardando',
            CameraPlaybackStatus.connecting => 'Conectando',
            CameraPlaybackStatus.playing => 'Ao vivo',
            CameraPlaybackStatus.reconnecting => 'Reconectando',
            CameraPlaybackStatus.error => 'Falha',
            CameraPlaybackStatus.paused => 'Pausada',
          }),
    );
  }

  Widget _diagnosticRow(int index, String name, String state) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        SizedBox(
          width: 28,
          child: Text(
            '${index + 1}',
            style: const TextStyle(color: Colors.white54),
          ),
        ),
        Expanded(
          child: Text(name, style: const TextStyle(color: Colors.white)),
        ),
        Text(
          state,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    ),
  );

  void _handleBack() {
    if (_focusedCameraId != null) {
      setState(() => _focusedCameraId = null);
      _syncSessions();
    } else if (_showDiagnostics) {
      _closeDiagnostics();
    } else if (!_showControls) {
      _revealControls();
    } else {
      widget.onExit();
    }
  }

  void _scheduleControlsHide() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _showControls && !_showDiagnostics) {
        setState(() => _showControls = false);
      }
    });
  }

  void _revealControls() {
    _controlsTimer?.cancel();
    if (!_showControls) setState(() => _showControls = true);
    _scheduleControlsHide();
  }

  void _closeDiagnostics() {
    setState(() => _showDiagnostics = false);
    _scheduleControlsHide();
  }

  Widget _toolbar(
    BuildContext context,
    AppStore store,
    LayoutPreset layout,
    int pages,
  ) {
    return Material(
      color: const Color(0xFF101722),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Voltar para início',
              onPressed: widget.onExit,
              icon: const Icon(Icons.arrow_back, color: Colors.white),
            ),
            IconButton(
              tooltip: _focusedCameraId == null
                  ? 'Ampliar câmera selecionada'
                  : 'Voltar à grade',
              onPressed: () {
                setState(() {
                  if (_focusedCameraId == null) {
                    final selectedIndex =
                        _page *
                        _pageSize(
                          store.activeLayout,
                          MediaQuery.sizeOf(context).width,
                        );
                    _focusedCameraId = store.config.slotCameraIds
                        .skip(selectedIndex)
                        .whereType<String>()
                        .firstOrNull;
                  } else {
                    _focusedCameraId = null;
                  }
                });
                _syncSessions();
              },
              icon: Icon(
                _focusedCameraId == null
                    ? Icons.fullscreen
                    : Icons.fullscreen_exit,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'MONITOR  ·  ${store.cameras.length} CÂMERAS',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            if (pages > 1 && _focusedCameraId == null)
              IconButton(
                onPressed: _page > 0
                    ? () {
                        setState(() => _page--);
                        _syncSessions();
                      }
                    : null,
                icon: const Icon(Icons.chevron_left, color: Colors.white),
              ),
            if (pages > 1 && _focusedCameraId == null)
              Text(
                '${_page + 1}/$pages',
                style: const TextStyle(color: Colors.white),
              ),
            if (pages > 1 && _focusedCameraId == null)
              IconButton(
                onPressed: _page + 1 < pages
                    ? () {
                        setState(() => _page++);
                        _syncSessions();
                      }
                    : null,
                icon: const Icon(Icons.chevron_right, color: Colors.white),
              ),
            IconButton(
              tooltip: _mainStreams ? 'Fluxo principal' : 'Fluxo econômico',
              onPressed: () {
                setState(() => _mainStreams = !_mainStreams);
                _restartSessions(store);
              },
              icon: Icon(
                _mainStreams
                    ? Icons.high_quality
                    : Icons.data_saver_on_outlined,
                color: Colors.white,
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Ações do monitor',
              iconColor: Colors.white,
              onSelected: (value) {
                if (value.startsWith('layout:')) {
                  store.setLayout(value.substring(7));
                } else if (value == 'hide') {
                  setState(() => _showControls = false);
                }
              },
              itemBuilder: (_) => [
                for (final preset in LayoutPreset.all.where(
                  (preset) =>
                      preset.id == 'SINGLE' ||
                      preset.id == 'GRID_2H' ||
                      preset.id == 'GRID_4' ||
                      preset.id == 'GRID_9' ||
                      preset.id == 'GRID_16',
                ))
                  PopupMenuItem(
                    value: 'layout:${preset.id}',
                    child: Text(preset.name),
                  ),
                const PopupMenuItem(
                  value: 'hide',
                  child: Text('Ocultar controles'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _restartSessions(AppStore store) {
    for (final session in _sessions.values) {
      unawaited(session.disposeSession());
    }
    _sessions.clear();
    _syncSessions();
  }

  int _columns(LayoutPreset layout, double width) {
    if (width < 600) return layout.cameraCount == 1 ? 1 : 2;
    if (width < 980) return layout.columns.clamp(1, 3);
    return layout.columns.clamp(1, 6);
  }

  int _pageSize(LayoutPreset layout, double width) => width < 600
      ? layout.cameraCount.clamp(1, 4)
      : width < 980
      ? layout.cameraCount.clamp(1, 9)
      : layout.cameraCount;
}

class _CameraTile extends StatelessWidget {
  const _CameraTile({
    required this.camera,
    required this.session,
    required this.onTap,
    required this.onFocus,
    required this.onRetry,
  });
  final CameraDevice? camera;
  final RtspSession? session;
  final VoidCallback onTap;
  final VoidCallback? onFocus;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onFocus,
      onSecondaryTap: onFocus,
      child: ColoredBox(
        color: const Color(0xFF111821),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (session?.videoController != null)
              Video(
                controller: session!.videoController!,
                fit: BoxFit.contain,
                fill: Colors.black,
                controls: NoVideoControls,
              )
            else
              const Center(
                child: Icon(
                  Icons.videocam_off_outlined,
                  size: 32,
                  color: Color(0xFF526174),
                ),
              ),
            if (camera == null)
              const Center(
                child: Text(
                  'Posição vazia',
                  style: TextStyle(color: Color(0xFF8A98AA)),
                ),
              ),
            if (camera != null && session?.videoController == null)
              Center(
                child: ValueListenableBuilder<CameraPlaybackStatus>(
                  valueListenable: session!.status,
                  builder: (context, status, _) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (status == CameraPlaybackStatus.connecting ||
                          status == CameraPlaybackStatus.reconnecting)
                        const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white70,
                          ),
                        )
                      else
                        IconButton(
                          onPressed: onRetry,
                          icon: const Icon(Icons.refresh, color: Colors.white),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        _status(status),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (camera != null)
              Positioned(
                left: 8,
                bottom: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.58),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 4,
                    ),
                    child: Text(
                      camera!.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _status(CameraPlaybackStatus status) => switch (status) {
    CameraPlaybackStatus.idle => 'Aguardando',
    CameraPlaybackStatus.connecting => 'Conectando…',
    CameraPlaybackStatus.playing => 'Ao vivo',
    CameraPlaybackStatus.reconnecting => 'Reconectando…',
    CameraPlaybackStatus.error => 'Falha na conexão',
    CameraPlaybackStatus.paused => 'Pausada',
  };
}

class _MonitorEmpty extends StatelessWidget {
  const _MonitorEmpty({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white70, fontSize: 16),
      ),
    ),
  );
}
