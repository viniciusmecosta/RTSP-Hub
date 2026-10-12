import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../camera_catalog/domain/camera_device.dart';
import '../domain/reconnect_policy.dart';

enum CameraPlaybackStatus {
  idle,
  connecting,
  playing,
  reconnecting,
  error,
  paused,
}

class RtspSession extends ChangeNotifier {
  RtspSession({
    required this.camera,
    required this.password,
    required this.defaultPort,
    required this.bufferMs,
    required this.useMainStream,
    this.firstFrameTimeout = const Duration(seconds: 8),
    this.retryEnabled = true,
  });

  final CameraDevice camera;
  final String? password;
  final int defaultPort;
  final int bufferMs;
  final bool useMainStream;
  final Duration firstFrameTimeout;
  final bool retryEnabled;
  final ValueNotifier<CameraPlaybackStatus> status = ValueNotifier(
    CameraPlaybackStatus.idle,
  );
  final ValueNotifier<String?> error = ValueNotifier(null);
  final ValueNotifier<bool> firstFrameRendered = ValueNotifier(false);
  Player? _player;
  VideoController? _videoController;
  StreamSubscription<String>? _errorSubscription;
  StreamSubscription<bool>? _playingSubscription;
  Timer? _retryTimer;
  int _generation = 0;
  int _failures = 0;
  int _totalReconnectAttempts = 0;
  bool _disposed = false;
  int? _firstFrameLatencyMs;
  Duration? _nextRetryDelay;

  Player? get player => _player;
  VideoController? get videoController => _videoController;
  int get reconnectAttempts => _totalReconnectAttempts;
  int? get firstFrameLatencyMs => _firstFrameLatencyMs;
  Duration? get nextRetryDelay => _nextRetryDelay;
  String? get currentResolution {
    final player = _player;
    if (player == null) return null;
    final track = player.state.tracks.video.firstWhere(
      (item) => item.id != 'auto' && item.id != 'no',
      orElse: () => player.state.track.video,
    );
    final width = track.w ?? player.state.videoParams.w;
    final height = track.h ?? player.state.videoParams.h;
    return width == null || height == null ? null : '$width×$height';
  }

  double? get currentFramesPerSecond {
    final player = _player;
    if (player == null) return null;
    final track = player.state.tracks.video.firstWhere(
      (item) => item.id != 'auto' && item.id != 'no',
      orElse: () => player.state.track.video,
    );
    final fps = track.fps;
    return fps == null || fps <= 0 ? null : fps;
  }

  int? get currentBitrate {
    final player = _player;
    if (player == null) return null;
    final bitrate = player.state.tracks.video
        .firstWhere(
          (item) => item.id != 'auto' && item.id != 'no',
          orElse: () => player.state.track.video,
        )
        .bitrate;
    return bitrate == null || bitrate <= 0 ? null : bitrate;
  }

  Future<void> start() async {
    if (_disposed || status.value == CameraPlaybackStatus.connecting) return;
    _retryTimer?.cancel();
    _nextRetryDelay = null;
    final generation = ++_generation;
    final started = Stopwatch()..start();
    status.value = _failures == 0
        ? CameraPlaybackStatus.connecting
        : CameraPlaybackStatus.reconnecting;
    error.value = null;
    firstFrameRendered.value = false;
    notifyListeners();
    try {
      MediaKit.ensureInitialized();
      final player = Player(
        configuration: PlayerConfiguration(
          bufferSize: bufferMs.clamp(100, 2000) * 4096,
          muted: true,
          logLevel: MPVLogLevel.error,
          protocolWhitelist: const [
            'rtsp',
            'tcp',
            'udp',
            'rtp',
            'tls',
            'crypto',
            'data',
            'file',
          ],
        ),
      );
      _player = player;
      _videoController = VideoController(
        player,
        configuration: VideoControllerConfiguration(
          scale: useMainStream ? 1 : 0.65,
          enableHardwareAcceleration: true,
        ),
      );
      _errorSubscription = player.stream.error.listen((message) {
        if (generation != _generation || _disposed) return;
        _markFailure(_safeMessage(message));
      });
      _playingSubscription = player.stream.playing.listen((playing) {
        if (generation != _generation || _disposed) return;
        if (playing) {
          status.value = CameraPlaybackStatus.playing;
          error.value = null;
        }
        notifyListeners();
      });
      if (generation != _generation || _disposed) {
        await _disposePlayer(player);
        return;
      }
      await player.open(Media(_mediaUri().toString()), play: true);
      await player.setAudioTrack(AudioTrack.no());
      final controller = _videoController;
      if (controller == null || generation != _generation || _disposed) return;
      await controller.waitUntilFirstFrameRendered.timeout(firstFrameTimeout);
      if (generation == _generation && !_disposed) {
        _firstFrameLatencyMs = started.elapsedMilliseconds;
        _failures = 0;
        firstFrameRendered.value = true;
        status.value = CameraPlaybackStatus.playing;
        error.value = null;
        notifyListeners();
      }
    } on Object catch (exception) {
      if (generation == _generation && !_disposed) {
        _markFailure(_safeMessage(exception));
      }
    }
  }

  Future<void> pause() async {
    ++_generation;
    _retryTimer?.cancel();
    final player = _player;
    if (player != null) {
      try {
        await player.pause();
      } on Object {
        debugPrint('Falha ao pausar a sessão RTSP.');
      }
    }
    status.value = CameraPlaybackStatus.paused;
    notifyListeners();
  }

  Future<void> resume() => start();

  Future<void> disposeSession() async {
    if (_disposed) return;
    _disposed = true;
    ++_generation;
    _retryTimer?.cancel();
    await _errorSubscription?.cancel();
    await _playingSubscription?.cancel();
    final player = _player;
    _player = null;
    _videoController = null;
    if (player != null) await _disposePlayer(player);
    status.value = CameraPlaybackStatus.idle;
    notifyListeners();
    status.dispose();
    error.dispose();
    firstFrameRendered.dispose();
    dispose();
  }

  Uri _mediaUri() {
    final path = useMainStream || camera.subPath.trim().isEmpty
        ? camera.mainPath
        : camera.subPath;
    final pathParts = path.split('?');
    final username = camera.username.isEmpty ? null : camera.username;
    final userInfo = username == null
        ? null
        : password == null || password!.isEmpty
        ? username
        : '$username:$password';
    return Uri(
      scheme: 'rtsp',
      userInfo: userInfo,
      host: camera.host,
      port: camera.effectivePort(defaultPort),
      path: pathParts.first.startsWith('/')
          ? pathParts.first
          : '/${pathParts.first}',
      query: pathParts.length > 1 ? pathParts.skip(1).join('?') : null,
    );
  }

  void _markFailure(String message) {
    ++_generation;
    final oldPlayer = _player;
    _player = null;
    _videoController = null;
    _errorSubscription?.cancel();
    _playingSubscription?.cancel();
    _errorSubscription = null;
    _playingSubscription = null;
    if (oldPlayer != null) unawaited(_disposePlayer(oldPlayer));
    _failures++;
    _totalReconnectAttempts++;
    error.value = message;
    status.value = retryEnabled
        ? CameraPlaybackStatus.reconnecting
        : CameraPlaybackStatus.error;
    if (retryEnabled) _scheduleRetry();
    notifyListeners();
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    _nextRetryDelay = _retryDelay();
    _retryTimer = Timer(_nextRetryDelay!, () {
      if (!_disposed) start();
    });
  }

  Duration _retryDelay() {
    return ReconnectPolicy.delayFor(
      _failures,
      jitterFactor: Random.secure().nextDouble(),
    );
  }

  Future<void> _disposePlayer(Player player) async {
    try {
      await player.stop().timeout(const Duration(milliseconds: 1800));
    } on Object {
      debugPrint('Falha ao encerrar a reprodução RTSP.');
    }
    try {
      await player.dispose().timeout(const Duration(milliseconds: 1800));
    } on Object {
      debugPrint('Falha ao liberar o player RTSP.');
    }
  }

  String _safeMessage(Object exception) {
    var message = exception.toString().replaceAll(
      RegExp(r'rtsp://\S+'),
      'rtsp://[oculto]',
    );
    if (password != null && password!.isNotEmpty) {
      message = message
          .replaceAll(password!, '[oculto]')
          .replaceAll(Uri.encodeComponent(password!), '[oculto]');
    }
    if (camera.host.isNotEmpty) {
      message = message.replaceAll(camera.host, '[endereço]');
    }
    return message;
  }
}
