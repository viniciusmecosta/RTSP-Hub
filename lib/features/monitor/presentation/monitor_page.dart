import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:window_manager/window_manager.dart';

import '../../../app/state/app_store.dart';
import '../../../features/camera_catalog/domain/camera_device.dart';
import '../../../features/camera_catalog/presentation/clone_camera_dialog.dart';
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

class _MonitorPageState extends State<MonitorPage> with WidgetsBindingObserver {
  final Map<String, RtspSession> _sessions = {};
  Timer? _controlsTimer;
  Timer? _diagnosticTimer;
  final ValueNotifier<int> _diagnosticTick = ValueNotifier(0);
  int _page = 0;
  bool _mainStreams = false;
  bool _showControls = true;
  bool _showDiagnostics = false;
  String? _focusedCameraId;
  int _generation = 0;
  bool _restoreMonitorPage = true;
  String? _lastLayoutId;
  bool _appActive = true;
  bool _refreshingDiagnostics = false;
  Future<void> _pendingTeardown = Future.value();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleControlsHide();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_appActive) {
        _appActive = true;
        _syncDiagnosticRefresh();
        unawaited(_syncSessions());
      }
      return;
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      if (!_appActive) return;
      _appActive = false;
      ++_generation;
      _diagnosticTimer?.cancel();
      _controlsTimer?.cancel();
      final sessions = _sessions.values.toList();
      _sessions.clear();
      unawaited(_releaseSessions(sessions));
      if (mounted) setState(() {});
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncSessions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ++_generation;
    _controlsTimer?.cancel();
    _diagnosticTimer?.cancel();
    _diagnosticTick.dispose();
    unawaited(_releaseSessions(_sessions.values.toList()));
    _sessions.clear();
    super.dispose();
  }

  Future<void> _syncSessions() async {
    if (!_appActive || !mounted) return;
    final generation = ++_generation;
    await _pendingTeardown;
    if (!_appActive || !mounted || generation != _generation) return;
    final store = AppScope.of(context);
    final ids = store.config.slotCameraIds;
    final cameraById = {for (final camera in store.cameras) camera.id: camera};
    if (_restoreMonitorPage) {
      _page = store.config.lastMonitorPage;
      _restoreMonitorPage = false;
    } else if (_lastLayoutId != null &&
        _lastLayoutId != store.config.layoutId) {
      _page = 0;
      unawaited(store.updateSettings(lastMonitorPage: 0));
    }
    _lastLayoutId = store.config.layoutId;
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
    final requestedIds =
        (_focusedCameraId == null ? pageSlots : <String?>[_focusedCameraId])
            .whereType<String>();
    final visibleIds = requestedIds.toSet();
    final staleSessions = <RtspSession>[];
    for (final id in _sessions.keys.toList()) {
      if (!visibleIds.contains(id)) {
        final old = _sessions.remove(id);
        if (old != null) staleSessions.add(old);
      }
    }
    await _releaseSessions(staleSessions);
    if (!mounted || generation != _generation) return;
    for (var index = start; index < end; index++) {
      final id = ids[index];
      if (id == null) continue;
      if (!visibleIds.contains(id)) continue;
      if (_focusedCameraId != null && id != _focusedCameraId) continue;
      final camera = cameraById[id];
      if (camera == null) continue;
      final secret = await store.passwordFor(camera);
      if (!mounted || generation != _generation) return;
      final effectiveCamera = camera.useGlobalCredentials
          ? camera.copyWith(username: store.config.defaultUser)
          : camera;
      final existing = _sessions[id];
      final mainStream =
          _mainStreams ||
          _focusedCameraId == id ||
          store.config.resourceMode == 'quality' ||
          camera.subPath.isEmpty;
      if (existing != null &&
          _sameCamera(existing.camera, effectiveCamera) &&
          existing.password == secret &&
          existing.defaultPort == store.config.defaultPort &&
          existing.bufferMs == store.config.bufferMs &&
          existing.useMainStream == mainStream) {
        continue;
      }
      if (existing != null) {
        _sessions.remove(id);
        await _releaseSessions([existing]);
        if (!mounted || generation != _generation || !_appActive) return;
      }
      final session = RtspSession(
        camera: effectiveCamera,
        password: secret,
        defaultPort: store.config.defaultPort,
        bufferMs: store.config.bufferMs,
        useMainStream: mainStream,
      );
      _sessions[id] = session;
      setState(() {});
      unawaited(session.start());
      if (index < end - 1) {
        await Future<void>.delayed(const Duration(milliseconds: 180));
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _releaseSessions(List<RtspSession> sessions) {
    if (sessions.isEmpty) return _pendingTeardown;
    final previous = _pendingTeardown;
    final pending = () async {
      await previous;
      await Future.wait(sessions.map((session) => session.disposeSession()));
    }();
    _pendingTeardown = pending;
    return pending;
  }

  bool _sameCamera(CameraDevice left, CameraDevice right) {
    return left.id == right.id &&
        left.name == right.name &&
        left.host == right.host &&
        left.port == right.port &&
        left.username == right.username &&
        left.mainPath == right.mainPath &&
        left.subPath == right.subPath &&
        left.useGlobalCredentials == right.useGlobalCredentials;
  }

  Future<void> _toggleWindowFullscreen() async {
    try {
      final fullscreen = await windowManager.isFullScreen();
      await windowManager.setFullScreen(!fullscreen);
    } on Object {
      return;
    }
  }

  void _changePage(int page, AppStore store) {
    setState(() => _page = page);
    unawaited(store.updateSettings(lastMonitorPage: page));
    unawaited(_syncSessions());
  }

  Set<String> _activePlaybackIds(AppStore store, List<String?> slots) {
    final pageSize = _pageSize(
      store.activeLayout,
      MediaQuery.sizeOf(context).width,
    );
    final requested = _focusedCameraId == null
        ? slots.skip(_page * pageSize).take(pageSize)
        : <String?>[_focusedCameraId];
    return requested.whereType<String>().toSet();
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
    final activeIds = _activePlaybackIds(store, slots);
    final cameraById = {for (final camera in store.cameras) camera.id: camera};
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
              _syncDiagnosticRefresh();
              if (!_showDiagnostics) _scheduleControlsHide();
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.f2) {
              widget.onConfigure();
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.pageUp ||
                event.logicalKey == LogicalKeyboardKey.pageDown) {
              final pageSize = _pageSize(
                AppScope.of(context).activeLayout,
                MediaQuery.sizeOf(context).width,
              );
              final pageCount =
                  ((AppScope.of(context).config.slotCameraIds.length +
                              pageSize -
                              1) ~/
                          pageSize)
                      .clamp(1, 100);
              final delta = event.logicalKey == LogicalKeyboardKey.pageUp
                  ? -1
                  : 1;
              final next = (_page + delta).clamp(0, pageCount - 1);
              if (next != _page) {
                _changePage(next, AppScope.of(context));
              }
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.f11) {
              unawaited(_toggleWindowFullscreen());
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.f4) {
              final layouts = LayoutPreset.all;
              final current = layouts.indexWhere(
                (item) => item.id == layout.id,
              );
              unawaited(
                AppScope.of(
                  context,
                ).setLayout(layouts[(current + 1) % layouts.length].id),
              );
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
                                    final columns = min(
                                      _columns(layout, constraints.maxWidth),
                                      sqrt(visibleCount).ceil().clamp(1, 6),
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
                                                  slots,
                                                  offset,
                                                  activeIds,
                                                  cameraById,
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
                                            slots,
                                            from + offset,
                                            activeIds,
                                            cameraById,
                                          ),
                                    );
                                  },
                                ),
                        ),
                        if (_showDiagnostics)
                          Positioned(
                            top: 12,
                            right: 12,
                            child: ListenableBuilder(
                              listenable: _diagnosticTick,
                              builder: (context, _) =>
                                  _diagnostics(context, store, slots),
                            ),
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

  Widget _cameraTile(
    List<String?> slots,
    int slotIndex,
    Set<String> activeIds,
    Map<String, CameraDevice> cameraById,
  ) {
    final id = slots[slotIndex];
    final camera = id == null ? null : cameraById[id];
    final session = id == null ? null : _sessions[id];
    return _CameraTile(
      camera: camera,
      session: session,
      waitingForResources: camera != null && !activeIds.contains(camera.id),
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
      onClone: camera == null
          ? null
          : () async {
              final cloned = await CloneCameraDialog.show(
                context,
                camera: camera,
                store: AppScope.of(context),
              );
              if (cloned == true && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Câmera “${camera.name}” clonada com sucesso.',
                    ),
                  ),
                );
              }
            },
      onSwitchChannel: camera == null || camera.savedPaths.length <= 1
          ? null
          : (newPath) async {
              await AppScope.of(context).switchCameraChannel(camera.id, newPath);
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
                    '${store.activeLayout.name} · cache ${store.config.bufferMs} · ${store.config.resourceMode}',
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
    if (session == null) {
      return _diagnosticRow(
        index,
        camera.name,
        'Em espera',
        'Pausada para respeitar o limite do perfil de desempenho.',
      );
    }
    return ValueListenableBuilder<CameraPlaybackStatus>(
      valueListenable: session.status,
      builder: (context, status, _) => _diagnosticRow(
        index,
        camera.name,
        switch (status) {
          CameraPlaybackStatus.idle => 'Aguardando',
          CameraPlaybackStatus.connecting => 'Conectando',
          CameraPlaybackStatus.playing => 'Ao vivo',
          CameraPlaybackStatus.reconnecting => 'Reconectando',
          CameraPlaybackStatus.error => 'Falha',
          CameraPlaybackStatus.paused => 'Pausada',
        },
        [
          if (session.currentResolution != null) session.currentResolution!,
          if (session.currentFramesPerSecond != null)
            '${session.currentFramesPerSecond!.toStringAsFixed(1)} fps nominal',
          if (session.currentBitrate != null)
            '${(session.currentBitrate! / 1000000).toStringAsFixed(1)} Mbps',
          if (session.hardwareDecoder case final decoder?
              when decoder.isNotEmpty)
            decoder == 'no' ? 'Decodificação por CPU' : 'Decodificação por GPU',
          if (session.droppedFrames case final dropped? when dropped > 0)
            '$dropped quadros perdidos',
          if (session.firstFrameLatencyMs != null)
            'Primeiro quadro ${session.firstFrameLatencyMs} ms',
          if (session.reconnectAttempts > 0)
            '${session.reconnectAttempts} tentativas de reconexão',
          if (session.nextRetryDelay case final delay?)
            'Nova tentativa em ${delay.inSeconds} s',
          if (session.error.value case final error? when error.isNotEmpty)
            error,
        ].join(' · '),
      ),
    );
  }

  Widget _diagnosticRow(int index, String name, String state, String details) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 28,
              child: Text(
                '${index + 1}',
                style: const TextStyle(color: Colors.white54),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(color: Colors.white)),
                  if (details.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        details,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
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
    _syncDiagnosticRefresh();
    _scheduleControlsHide();
  }

  void _syncDiagnosticRefresh() {
    _diagnosticTimer?.cancel();
    if (_showDiagnostics && _appActive) {
      unawaited(_refreshDiagnosticMetrics());
      _diagnosticTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        unawaited(_refreshDiagnosticMetrics());
      });
    }
  }

  Future<void> _refreshDiagnosticMetrics() async {
    if (_refreshingDiagnostics || !_appActive || !mounted) return;
    _refreshingDiagnostics = true;
    try {
      await Future.wait(
        _sessions.values.map((session) => session.refreshDiagnostics()),
      );
      if (mounted && _appActive && _showDiagnostics) {
        _diagnosticTick.value++;
      }
    } finally {
      _refreshingDiagnostics = false;
    }
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
                    ? () => _changePage(_page - 1, store)
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
                    ? () => _changePage(_page + 1, store)
                    : null,
                icon: const Icon(Icons.chevron_right, color: Colors.white),
              ),
            IconButton(
              tooltip: _mainStreams ? 'Fluxo principal' : 'Fluxo econômico',
              onPressed: () {
                setState(() => _mainStreams = !_mainStreams);
                unawaited(_restartSessions());
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
                } else if (value == 'shortcuts') {
                  _showKeyboardShortcuts(context);
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
                const PopupMenuItem(
                  value: 'shortcuts',
                  child: Text('Atalhos do teclado'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _restartSessions() async {
    ++_generation;
    final oldSessions = _sessions.values.toList();
    _sessions.clear();
    setState(() {});
    await _releaseSessions(oldSessions);
    if (mounted && _appActive) await _syncSessions();
  }

  Future<void> _showKeyboardShortcuts(BuildContext context) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Atalhos do monitor'),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('F11 · alternar tela cheia'),
          Text('F4 · trocar layout'),
          Text('Page Up / Page Down · trocar página'),
          Text('F3 · abrir ou fechar diagnósticos'),
          Text('F2 · configurar câmeras'),
          Text('Esc · voltar à grade ou sair do monitor'),
          SizedBox(height: 12),
          Text('Clique duplo em uma câmera para focá-la.'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fechar'),
        ),
      ],
    ),
  );

  int _columns(LayoutPreset layout, double width) {
    if (width < 600) return layout.cameraCount == 1 ? 1 : 2;
    if (width < 980) return layout.columns.clamp(1, 3);
    return layout.columns.clamp(1, 6);
  }

  int _pageSize(LayoutPreset layout, double width) {
    return layout.cameraCount;
  }
}

class _CameraTile extends StatelessWidget {
  const _CameraTile({
    required this.camera,
    required this.session,
    required this.waitingForResources,
    required this.onTap,
    required this.onFocus,
    this.onClone,
    this.onSwitchChannel,
    required this.onRetry,
  });
  final CameraDevice? camera;
  final RtspSession? session;
  final bool waitingForResources;
  final VoidCallback onTap;
  final VoidCallback? onFocus;
  final VoidCallback? onClone;
  final ValueChanged<String>? onSwitchChannel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final currentSession = session;
    if (currentSession == null) return _content(context);
    return ListenableBuilder(
      listenable: currentSession,
      builder: (context, _) => _content(context),
    );
  }

  Widget _content(BuildContext context) {
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
            else if (camera != null && waitingForResources)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.memory_outlined, color: Colors.white70),
                    const SizedBox(height: 6),
                    const Text(
                      'Em espera para poupar recursos',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    TextButton(
                      onPressed: onFocus,
                      child: const Text('Focar câmera'),
                    ),
                  ],
                ),
              )
            else if (camera == null)
              const Center(
                child: Icon(
                  Icons.videocam_off_outlined,
                  size: 32,
                  color: Color(0xFF526174),
                ),
              )
            else
              const Center(
                child: Text(
                  'Preparando câmera…',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            if (camera == null)
              const Center(
                child: Text(
                  'Posição vazia',
                  style: TextStyle(color: Color(0xFF8A98AA)),
                ),
              ),
            if (camera != null &&
                session != null &&
                session!.videoController == null)
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
                      camera!.savedPaths.length > 1
                          ? '${camera!.name} (${camera!.mainPath})'
                          : camera!.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            if (camera != null)
              Positioned(
                top: 6,
                right: 6,
                child: Material(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(16),
                  child: PopupMenuButton<String>(
                    tooltip: 'Opções da câmera',
                    icon: const Icon(
                      Icons.more_vert,
                      color: Colors.white,
                      size: 18,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 140),
                    onSelected: (value) {
                      if (value == 'focus') {
                        onFocus?.call();
                      } else if (value == 'clone') {
                        onClone?.call();
                      } else if (value.startsWith('channel:')) {
                        onSwitchChannel?.call(value.substring('channel:'.length));
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'focus',
                        child: Row(
                          children: const [
                            Icon(Icons.fullscreen, size: 18),
                            SizedBox(width: 8),
                            Text('Focar câmera'),
                          ],
                        ),
                      ),
                      if (onClone != null)
                        const PopupMenuItem(
                          value: 'clone',
                          child: Row(
                            children: [
                              Icon(Icons.copy_outlined, size: 18),
                              SizedBox(width: 8),
                              Text('Clonar câmera'),
                            ],
                          ),
                        ),
                      if (camera != null && camera!.savedPaths.length > 1) ...[
                        const PopupMenuDivider(),
                        ...camera!.savedPaths.map(
                          (path) => PopupMenuItem(
                            value: 'channel:$path',
                            child: Row(
                              children: [
                                Icon(
                                  path == camera!.mainPath
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  size: 16,
                                  color: path == camera!.mainPath
                                      ? const Color(0xFF10B981)
                                      : Colors.white70,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Canal: $path',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: path == camera!.mainPath
                                          ? FontWeight.w700
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
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
