import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../../../app/state/app_store.dart';
import '../../../features/camera_catalog/domain/camera_device.dart';
import '../../../features/layouts/domain/layout_preset.dart';
import '../application/rtsp_session.dart';
import '../application/rtsp_connection_coordinator.dart';
import '../domain/stream_selection_policy.dart';
import '../domain/monitor_paging_policy.dart';
import '../../../shared/platform/device_environment.dart';
import 'widgets/monitor_camera_tile.dart';
import 'widgets/monitor_camera_viewport.dart';

typedef MonitorSessionFactory =
    RtspSession Function({
      required CameraDevice camera,
      required String? password,
      required int defaultPort,
      required int bufferMs,
      required bool useMainStream,
      required RtspConnectionCoordinator connectionCoordinator,
      required int connectionPriority,
    });

class MonitorPage extends StatefulWidget {
  const MonitorPage({
    required this.onExit,
    required this.onConfigure,
    this.onOpenLayouts,
    this.sessionFactory = RtspSession.new,
    this.now = DateTime.now,
    super.key,
  });

  final VoidCallback onExit;
  final VoidCallback onConfigure;
  final VoidCallback? onOpenLayouts;
  final MonitorSessionFactory sessionFactory;
  final DateTime Function() now;

  @override
  State<MonitorPage> createState() => _MonitorPageState();
}

class _MonitorPageState extends State<MonitorPage> with WidgetsBindingObserver {
  final Map<String, RtspSession> _sessions = {};
  final Set<String> _snapshotAttempts = {};
  final _connections = RtspConnectionCoordinator();
  final _toolbarFocus = FocusNode(
    debugLabel: 'Monitor toolbar',
    skipTraversal: true,
  );
  Timer? _controlsTimer;
  Timer? _diagnosticTimer;
  final ValueNotifier<int> _diagnosticTick = ValueNotifier(0);
  int _page = 0;
  bool? _mainStreams;
  final ValueNotifier<bool> _controlsVisible = ValueNotifier(false);
  late DateTime _lastInteraction;
  bool get _showControls => _controlsVisible.value;
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
    _lastInteraction = widget.now();
    _controlsVisible.addListener(_syncSystemUiMode);
    _syncSystemUiMode();
  }

  void _syncSystemUiMode() {
    if (kIsWeb) return;
    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      unawaited(
        SystemChrome.setEnabledSystemUIMode(
          _controlsVisible.value
              ? SystemUiMode.edgeToEdge
              : SystemUiMode.immersiveSticky,
        ),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_appActive) {
        _appActive = true;
        _syncDiagnosticRefresh();
        _syncSystemUiMode();
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
    _controlsVisible.removeListener(_syncSystemUiMode);
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    }
    _diagnosticTick.dispose();
    _controlsVisible.dispose();
    _toolbarFocus.dispose();
    unawaited(_releaseSessions(_sessions.values.toList()));
    _sessions.clear();
    _connections.dispose();
    super.dispose();
  }

  Future<void> _syncSessions() async {
    if (!_appActive || !mounted) return;
    final generation = ++_generation;
    await _pendingTeardown;
    if (!_appActive || !mounted || generation != _generation) return;
    final store = AppScope.of(context);
    final television = DeviceEnvironmentScope.of(context).isTelevision;
    _connections.configure(
      maxConcurrent: television || store.config.resourceMode == 'light' ? 1 : 2,
      spacing: Duration(
        milliseconds: television
            ? 400
            : store.config.resourceMode == 'light'
            ? 300
            : 180,
      ),
    );
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
    final pages = max(1, (ids.length + pageSize - 1) ~/ pageSize);
    _page = _page.clamp(0, pages - 1);
    if (_focusedCameraId != null && !ids.contains(_focusedCameraId)) {
      _focusedCameraId = null;
    }
    final start = _page * pageSize;
    final end = (start + pageSize).clamp(0, ids.length);
    final pageSlots = ids.sublist(start, end);
    final visibleIds = pageSlots
        .whereType<String>()
        .where(cameraById.containsKey)
        .toSet();
    if (_focusedCameraId != null && !visibleIds.contains(_focusedCameraId)) {
      _focusedCameraId = null;
    }
    _syncBackgroundSessions();
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
      final camera = cameraById[id];
      if (camera == null) continue;
      final secret = await store.passwordFor(camera);
      if (!mounted || generation != _generation) return;
      final effectiveCamera = store.resolveCamera(camera);
      final existing = _sessions[id];
      final mainStream = StreamSelectionPolicy.useMainStream(
        resourceMode: store.config.resourceMode,
        defaultStreamMode: store.config.defaultStreamMode,
        manualChoice: _mainStreams,
        hasSubStream: effectiveCamera.activeChannel?.sub != null,
      );
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
      final session = widget.sessionFactory(
        camera: effectiveCamera,
        password: secret,
        defaultPort: store.config.defaultPort,
        bufferMs: store.config.bufferMs,
        useMainStream: mainStream,
        connectionCoordinator: _connections,
        connectionPriority: _focusedCameraId == id ? 10 : 0,
      );
      _sessions[id] = session;
      unawaited(
        session.setBackground(
          _focusedCameraId != null && _focusedCameraId != id,
        ),
      );
      _captureFirstSnapshot(camera, session);
      setState(() {});
      unawaited(session.start());
    }
    if (mounted) setState(() {});
  }

  void _captureFirstSnapshot(CameraDevice camera, RtspSession session) {
    if (camera.thumbnailCapturedAt != null ||
        !_snapshotAttempts.add(camera.id)) {
      return;
    }
    late final VoidCallback listener;
    listener = () {
      if (!session.firstFrameRendered.value) return;
      session.firstFrameRendered.removeListener(listener);
      unawaited(_saveSnapshot(camera.id, session));
    };
    session.firstFrameRendered.addListener(listener);
  }

  Future<void> _saveSnapshot(String cameraId, RtspSession session) async {
    final store = AppScope.of(context);
    try {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!mounted || _sessions[cameraId] != session) {
        _snapshotAttempts.remove(cameraId);
        return;
      }
      final bytes = await session.player?.screenshot().timeout(
        const Duration(seconds: 3),
      );
      if (bytes == null || !mounted) {
        _snapshotAttempts.remove(cameraId);
        return;
      }
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
          if (data == null) return;
          await store.updateCameraSnapshot(
            cameraId,
            data.buffer.asUint8List(),
            capturedAt: capturedAt,
          );
        } finally {
          frame.image.dispose();
        }
      } finally {
        codec.dispose();
      }
    } on Object {
      _snapshotAttempts.remove(cameraId);
    }
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
        left.selectedPath == right.selectedPath &&
        left.selectedChannelId == right.selectedChannelId &&
        listEquals(left.channels, right.channels) &&
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
    setState(() {
      _page = page;
      _focusedCameraId = null;
    });
    unawaited(store.updateSettings(lastMonitorPage: page));
    unawaited(_syncSessions());
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final layout = store.activeLayout;
    final slots = store.config.slotCameraIds;
    final perPage = _pageSize(layout, MediaQuery.sizeOf(context).width);
    final pages = max(1, (slots.length + perPage - 1) ~/ perPage);
    if (_page >= pages) _page = pages - 1;
    final focusedIndex = _focusedCameraId == null
        ? -1
        : slots.indexOf(_focusedCameraId!);
    final from = _page * perPage;
    final visibleCount = (slots.length - from).clamp(0, perPage);
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
            if (!_showControls &&
                {
                  LogicalKeyboardKey.arrowUp,
                  LogicalKeyboardKey.arrowDown,
                  LogicalKeyboardKey.arrowLeft,
                  LogicalKeyboardKey.arrowRight,
                  LogicalKeyboardKey.select,
                  LogicalKeyboardKey.enter,
                  LogicalKeyboardKey.gameButtonA,
                }.contains(event.logicalKey)) {
              _revealControls();
              return KeyEventResult.handled;
            }
            _revealControls();
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
              final pageCount = max(
                1,
                (AppScope.of(context).config.slotCameraIds.length +
                        pageSize -
                        1) ~/
                    pageSize,
              );
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
        child: ValueListenableBuilder<bool>(
          valueListenable: _controlsVisible,
          builder: (context, visible, child) => MouseRegion(
            cursor: visible
                ? SystemMouseCursors.basic
                : SystemMouseCursors.none,
            onHover: (event) {
              if (event.delta != Offset.zero) _revealControls();
            },
            child: Listener(
              onPointerDown: (_) => _revealControls(),
              child: child,
            ),
          ),
          child: Scaffold(
            backgroundColor: const Color(0xFF06090F),
            body: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: RepaintBoundary(
                    key: const ValueKey('monitorViewport'),
                    child: store.cameras.isEmpty
                        ? const MonitorEmptyView(
                            message:
                                'Cadastre câmeras para começar a visualizar.',
                          )
                        : visibleCount == 0
                        ? const MonitorEmptyView(
                            message:
                                'A grade está vazia. Associe câmeras em Layouts.',
                          )
                        : MonitorCameraViewport(
                            layout: layout,
                            pageStart: from,
                            freeformSlots: store.config.freeformSlots,
                            focusedIndex:
                                focusedIndex >= from &&
                                    focusedIndex < from + visibleCount
                                ? focusedIndex - from
                                : null,
                            children: [
                              for (
                                var offset = 0;
                                offset < visibleCount;
                                offset++
                              )
                                _cameraTile(slots, from + offset, cameraById),
                            ],
                          ),
                  ),
                ),

                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _controlsVisible,
                    builder: (context, visible, _) => visible
                        ? SafeArea(
                            bottom: false,
                            child: Focus(
                              focusNode: _toolbarFocus,
                              child: _toolbar(context, store, layout, pages),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
                if (_showDiagnostics && !store.config.simpleMode)
                  Positioned(
                    top: 76,
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
        ),
      ),
    );
  }

  Widget _cameraTile(
    List<String?> slots,
    int slotIndex,
    Map<String, CameraDevice> cameraById,
  ) {
    final store = AppScope.of(context);
    final id = slots[slotIndex];
    final camera = id == null ? null : cameraById[id];
    final session = id == null ? null : _sessions[id];
    return MonitorCameraTile(
      key: ValueKey('monitor-camera-slot-$slotIndex'),
      camera: camera,
      simpleMode: store.config.simpleMode,
      fitMode: store.config.videoFitMode,
      autofocus:
          DeviceEnvironmentScope.of(context).isTelevision &&
          camera != null &&
          (slotIndex ==
                  _page *
                      _pageSize(
                        store.activeLayout,
                        MediaQuery.sizeOf(context).width,
                      ) ||
              _focusedCameraId == id),
      session: session,
      onTap: () {
        if (camera != null) {
          setState(() {
            _focusedCameraId = _focusedCameraId == camera.id ? null : camera.id;
          });
          _syncBackgroundSessions();
        } else {
          _revealControls();
        }
      },
      onFocus: camera == null
          ? null
          : () {
              if (!_showControls) {
                _revealControls();
                return;
              }
              setState(() {
                _focusedCameraId = _focusedCameraId == camera.id
                    ? null
                    : camera.id;
              });
              _syncBackgroundSessions();
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
        'Aguardando a abertura desta câmera.',
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

  void _syncBackgroundSessions() {
    for (final entry in _sessions.entries) {
      unawaited(
        entry.value.setBackground(
          _focusedCameraId != null && entry.key != _focusedCameraId,
        ),
      );
    }
  }

  void _handleBack() {
    if (_focusedCameraId != null) {
      setState(() => _focusedCameraId = null);
      _syncBackgroundSessions();
    } else if (_showDiagnostics) {
      _closeDiagnostics();
    } else if (!_showControls) {
      _revealControls();
    } else {
      widget.onExit();
    }
  }

  void _scheduleControlsHide() {
    _lastInteraction = widget.now();
    if (_controlsTimer?.isActive ?? false) return;
    _controlsTimer = Timer(const Duration(seconds: 4), _hideControlsWhenIdle);
  }

  void _hideControlsWhenIdle() {
    if (!mounted || !_appActive || _showDiagnostics) return;
    if (ModalRoute.of(context)?.isCurrent == false || _toolbarFocus.hasFocus) {
      _scheduleControlsHide();
      return;
    }
    final remaining =
        const Duration(seconds: 4) - widget.now().difference(_lastInteraction);
    if (remaining > Duration.zero) {
      _controlsTimer = Timer(remaining, _hideControlsWhenIdle);
    } else {
      _controlsVisible.value = false;
    }
  }

  void _revealControls() {
    if (!_appActive) return;
    _controlsVisible.value = true;
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
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 600;
    final veryCompact = width < 380;
    final mainStreams = StreamSelectionPolicy.useMainStream(
      resourceMode: store.config.resourceMode,
      defaultStreamMode: store.config.defaultStreamMode,
      manualChoice: _mainStreams,
    );
    final desktop =
        !kIsWeb &&
        {
          TargetPlatform.windows,
          TargetPlatform.linux,
          TargetPlatform.macOS,
        }.contains(defaultTargetPlatform);
    return Material(
      color: const Color(0xFF101C2E),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: veryCompact ? 4 : 12,
          vertical: veryCompact ? 3 : 6,
        ),
        child: Row(
          children: [
            IconButton(
              visualDensity: veryCompact ? VisualDensity.compact : null,
              tooltip: 'Voltar para início',
              onPressed: widget.onExit,
              icon: const Icon(Icons.arrow_back, color: Colors.white),
            ),
            IconButton(
              visualDensity: veryCompact ? VisualDensity.compact : null,
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
                        .take(
                          _pageSize(
                            store.activeLayout,
                            MediaQuery.sizeOf(context).width,
                          ),
                        )
                        .whereType<String>()
                        .firstOrNull;
                  } else {
                    _focusedCameraId = null;
                  }
                });
                _syncBackgroundSessions();
              },
              icon: Icon(
                _focusedCameraId == null
                    ? Icons.fullscreen
                    : Icons.fullscreen_exit,
                color: Colors.white,
              ),
            ),
            SizedBox(width: veryCompact ? 2 : 4),
            Expanded(
              child: Text(
                veryCompact
                    ? 'MONITOR'
                    : 'MONITOR  ·  ${store.cameras.length} CÂMERAS',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: veryCompact ? 11 : (compact ? 12 : 14),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            if (pages > 1 && _focusedCameraId == null && !compact)
              IconButton(
                tooltip: 'Página anterior',
                onPressed: _page > 0
                    ? () => _changePage(_page - 1, store)
                    : null,
                icon: Icon(
                  Icons.chevron_left,
                  color: _page > 0 ? Colors.white : Colors.white38,
                ),
              ),
            if (pages > 1 && _focusedCameraId == null && !compact)
              Text(
                '${_page + 1}/$pages',
                style: const TextStyle(color: Colors.white),
              ),
            if (pages > 1 && _focusedCameraId == null && !compact)
              IconButton(
                tooltip: 'Próxima página',
                onPressed: _page + 1 < pages
                    ? () => _changePage(_page + 1, store)
                    : null,
                icon: Icon(
                  Icons.chevron_right,
                  color: _page + 1 < pages ? Colors.white : Colors.white38,
                ),
              ),
            if (!store.config.simpleMode)
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Tooltip(
                      message: 'Alta Definição (HD - Fluxo principal)',
                      child: InkWell(
                        key: const ValueKey('monitor-stream-hd'),
                        borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(7),
                        ),
                        onTap: () {
                          if (_mainStreams != true) {
                            setState(() => _mainStreams = true);
                            unawaited(_restartSessions());
                          }
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: veryCompact ? 6 : 9,
                            vertical: veryCompact ? 4 : 5,
                          ),
                          decoration: BoxDecoration(
                            color: mainStreams
                                ? const Color(0xFF2563EB)
                                : Colors.transparent,
                            borderRadius: const BorderRadius.horizontal(
                              left: Radius.circular(7),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.hd,
                                size: 16,
                                color: mainStreams
                                    ? Colors.white
                                    : const Color(0xFF94A3B8),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'HD',
                                style: TextStyle(
                                  color: mainStreams
                                      ? Colors.white
                                      : const Color(0xFF94A3B8),
                                  fontSize: 12,
                                  fontWeight: mainStreams
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Tooltip(
                      message: 'Econômico (SD - Subfluxo)',
                      child: InkWell(
                        key: const ValueKey('monitor-stream-sd'),
                        borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(7),
                        ),
                        onTap: () {
                          if (_mainStreams != false) {
                            setState(() => _mainStreams = false);
                            unawaited(_restartSessions());
                          }
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: veryCompact ? 6 : 9,
                            vertical: veryCompact ? 4 : 5,
                          ),
                          decoration: BoxDecoration(
                            color: !mainStreams
                                ? const Color(0xFF0D9488)
                                : Colors.transparent,
                            borderRadius: const BorderRadius.horizontal(
                              right: Radius.circular(7),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.sd,
                                size: 16,
                                color: !mainStreams
                                    ? Colors.white
                                    : const Color(0xFF94A3B8),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'SD',
                                style: TextStyle(
                                  color: !mainStreams
                                      ? Colors.white
                                      : const Color(0xFF94A3B8),
                                  fontSize: 12,
                                  fontWeight: !mainStreams
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(width: veryCompact ? 2 : 6),
            PopupMenuButton<String>(
              padding: veryCompact
                  ? EdgeInsets.zero
                  : const EdgeInsets.all(8.0),
              tooltip: 'Ações do monitor',
              iconColor: Colors.white,
              onSelected: (value) {
                if (value == 'mode') {
                  store.updateSettings(simpleMode: !store.config.simpleMode);
                } else if (value.startsWith('layout:')) {
                  store.setLayout(value.substring(7));
                } else if (value == 'auto-quality') {
                  setState(() => _mainStreams = null);
                  unawaited(_restartSessions());
                } else if (value == 'cameras') {
                  widget.onConfigure();
                } else if (value == 'layouts') {
                  widget.onOpenLayouts?.call();
                } else if (value == 'previous') {
                  _changePage(_page - 1, store);
                } else if (value == 'next') {
                  _changePage(_page + 1, store);
                } else if (value == 'diagnostics') {
                  setState(() => _showDiagnostics = !_showDiagnostics);
                  _syncDiagnosticRefresh();
                  _revealControls();
                } else if (value == 'fullscreen') {
                  unawaited(_toggleWindowFullscreen());
                } else if (value == 'hide') {
                  _controlsVisible.value = false;
                } else if (value == 'shortcuts') {
                  _showKeyboardShortcuts(context);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'mode',
                  child: Text(
                    store.config.simpleMode ? 'Modo Avançado' : 'Modo Simples',
                  ),
                ),
                if (_mainStreams != null)
                  const PopupMenuItem(
                    value: 'auto-quality',
                    child: Text('Usar qualidade automática'),
                  ),
                const PopupMenuItem(
                  value: 'cameras',
                  child: Text('Configurar câmeras'),
                ),
                if (widget.onOpenLayouts != null)
                  const PopupMenuItem(
                    value: 'layouts',
                    child: Text('Editar layout e perfis'),
                  ),
                if (!store.config.simpleMode)
                  PopupMenuItem(
                    value: 'diagnostics',
                    child: Text(
                      _showDiagnostics
                          ? 'Fechar diagnósticos'
                          : 'Diagnósticos das câmeras',
                    ),
                  ),
                if (desktop)
                  const PopupMenuItem(
                    value: 'fullscreen',
                    child: Text('Alternar tela cheia'),
                  ),
                if (compact && pages > 1) ...[
                  PopupMenuItem(
                    value: 'previous',
                    enabled: _page > 0,
                    child: const Text('Página anterior'),
                  ),
                  PopupMenuItem(
                    value: 'next',
                    enabled: _page + 1 < pages,
                    child: const Text('Próxima página'),
                  ),
                ],
                const PopupMenuDivider(),
                for (final preset in LayoutPreset.all.where(
                  (preset) =>
                      preset.id == 'FREEFORM' ||
                      preset.id == 'SINGLE' ||
                      preset.id == 'GRID_2H' ||
                      preset.id == 'GRID_4' ||
                      preset.id == 'GRID_9' ||
                      preset.id == 'GRID_16' ||
                      preset.id == 'GRID_ALL',
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
                  child: Text('Teclado e controle remoto'),
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
          Text('Setas · navegar entre câmeras e botões'),
          Text('OK / Enter · ampliar a câmera selecionada'),
          Text('Voltar · retornar à grade ou sair do monitor'),
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

  int _pageSize(LayoutPreset layout, double width) {
    return MonitorPagingPolicy.pageSize(
      cameraCount: layout.cameraCount,
      preference: AppScope.of(context).config.monitorPageSize,
      television: DeviceEnvironmentScope.of(context).isTelevision,
    );
  }
}
