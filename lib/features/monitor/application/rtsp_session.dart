import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../camera_catalog/domain/camera_device.dart';
import '../domain/rtsp_buffer_policy.dart';
import '../domain/reconnect_policy.dart';
import '../domain/rtsp_failure_message.dart';
import '../domain/rtsp_stream_uri.dart';

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
  StreamSubscription<Duration>? _positionSubscription;
  Timer? _retryTimer;
  Timer? _stallTimer;
  Timer? _progressTimer;
  Future<void>? _starting;
  Future<void>? _closing;
  Future<void>? _disposing;
  int _generation = 0;
  int _failures = 0;
  int _totalReconnectAttempts = 0;
  bool _disposed = false;
  int? _firstFrameLatencyMs;
  Duration? _nextRetryDelay;
  Duration _lastPosition = Duration.zero;
  DateTime? _lastPositionAdvanced;
  bool authenticationFailed = false;
  String? _hardwareDecoder;
  int? _droppedFrames;

  Player? get player => _player;
  VideoController? get videoController => _videoController;
  int get reconnectAttempts => _totalReconnectAttempts;
  int? get firstFrameLatencyMs => _firstFrameLatencyMs;
  Duration? get nextRetryDelay => _nextRetryDelay;
  String? get hardwareDecoder => _hardwareDecoder;
  int? get droppedFrames => _droppedFrames;

  Future<void> refreshDiagnostics() async {
    final currentPlayer = _player;
    final backend = currentPlayer?.platform;
    if (_disposed || backend is! NativePlayer || !firstFrameRendered.value) {
      return;
    }
    try {
      final decoder = await backend.getProperty('hwdec-current');
      if (identical(_player, currentPlayer)) _hardwareDecoder = decoder;
    } on Object {
      if (identical(_player, currentPlayer)) _hardwareDecoder = null;
    }
    try {
      final rendered = await backend.getProperty('frame-drop-count');
      final decoded = await backend.getProperty('decoder-frame-drop-count');
      if (identical(_player, currentPlayer)) {
        _droppedFrames =
            (int.tryParse(rendered) ?? 0) + (int.tryParse(decoded) ?? 0);
      }
    } on Object {
      if (identical(_player, currentPlayer)) _droppedFrames = null;
    }
  }

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

  Future<void> start() {
    if (_disposed) return Future.value();
    if (status.value == CameraPlaybackStatus.playing && _player != null) {
      return Future.value();
    }
    final pending = _starting;
    if (pending != null) {
      if (status.value == CameraPlaybackStatus.paused ||
          status.value == CameraPlaybackStatus.error ||
          status.value == CameraPlaybackStatus.reconnecting) {
        return pending.then((_) async {
          if (_disposed ||
              status.value == CameraPlaybackStatus.playing ||
              status.value == CameraPlaybackStatus.connecting) {
            return;
          }
          await start();
        });
      }
      return pending;
    }
    final operation = _start();
    late final Future<void> tracked;
    tracked = operation.whenComplete(() {
      if (identical(_starting, tracked)) _starting = null;
    });
    _starting = tracked;
    return tracked;
  }

  Future<void> _start() async {
    _retryTimer?.cancel();
    _progressTimer?.cancel();
    _nextRetryDelay = null;
    authenticationFailed = false;
    _lastPosition = Duration.zero;
    _lastPositionAdvanced = null;
    _hardwareDecoder = null;
    _droppedFrames = null;
    final generation = ++_generation;
    final started = Stopwatch()..start();
    status.value = _failures == 0
        ? CameraPlaybackStatus.connecting
        : CameraPlaybackStatus.reconnecting;
    error.value = null;
    firstFrameRendered.value = false;
    notifyListeners();
    try {
      final closing = _closing;
      if (closing != null) await closing;
      if (generation != _generation || _disposed) return;
      MediaKit.ensureInitialized();
      final player = Player(
        configuration: PlayerConfiguration(
          bufferSize: RtspBufferPolicy.bytesFor(
            targetMilliseconds: bufferMs,
            mainStream: useMainStream,
          ),
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
      final backend = player.platform;
      if (backend is NativePlayer) {
        await backend.setProperty('cache-on-disk', 'no');
        await backend.setProperty('aid', 'no');
      }
      if (generation != _generation || _disposed) {
        await _closePlayer(player);
        return;
      }
      _videoController = VideoController(
        player,
        configuration: const VideoControllerConfiguration(
          enableHardwareAcceleration: true,
        ),
      );
      notifyListeners();
      _errorSubscription = player.stream.error.listen((message) {
        if (generation != _generation || _disposed) return;
        if (firstFrameRendered.value && player.state.playing) return;
        authenticationFailed = RtspFailureMessage.isAuthenticationFailure(
          message,
        );
        _markFailure(
          RtspFailureMessage.describe(message),
          retry: RtspFailureMessage.canRetry(message),
        );
      });
      _positionSubscription = player.stream.position.listen((position) {
        if (generation != _generation || _disposed) return;
        if (position > _lastPosition ||
            (position > Duration.zero && position < _lastPosition)) {
          _lastPositionAdvanced = DateTime.now();
        }
        _lastPosition = position;
      });
      _progressTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (generation != _generation ||
            _disposed ||
            !firstFrameRendered.value ||
            !player.state.playing) {
          return;
        }
        final advanced = _lastPositionAdvanced;
        if (advanced != null &&
            DateTime.now().difference(advanced) > const Duration(seconds: 12)) {
          _markFailure(
            'O vídeo parou de avançar. Tentando restabelecer a conexão.',
          );
        }
      });
      _playingSubscription = player.stream.playing.listen((playing) {
        if (generation != _generation || _disposed) return;
        if (playing) {
          _stallTimer?.cancel();
          status.value = CameraPlaybackStatus.playing;
          error.value = null;
        } else if (firstFrameRendered.value) {
          _stallTimer?.cancel();
          _stallTimer = Timer(const Duration(seconds: 10), () {
            if (!_disposed &&
                generation == _generation &&
                _player?.state.playing == false) {
              _markFailure(
                'O vídeo parou de responder. Tentando restabelecer a conexão.',
              );
            }
          });
        }
        notifyListeners();
      });
      if (generation != _generation || _disposed) {
        await _disposePlayer(player);
        return;
      }
      await player
          .open(Media(_streamUri.toString()), play: true)
          .timeout(firstFrameTimeout);
      if (generation != _generation || _disposed) return;
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
        authenticationFailed = RtspFailureMessage.isAuthenticationFailure(
          exception,
        );
        _markFailure(
          RtspFailureMessage.describe(exception),
          retry: RtspFailureMessage.canRetry(exception),
        );
      }
    }
  }

  Future<void> pause() async {
    if (_disposed) return;
    ++_generation;
    _retryTimer?.cancel();
    _stallTimer?.cancel();
    _progressTimer?.cancel();
    _nextRetryDelay = null;
    final player = _player;
    _player = null;
    _videoController = null;
    firstFrameRendered.value = false;
    await _errorSubscription?.cancel();
    await _playingSubscription?.cancel();
    await _positionSubscription?.cancel();
    _errorSubscription = null;
    _playingSubscription = null;
    _positionSubscription = null;
    if (player != null) {
      await _closePlayer(player);
    }
    if (!_disposed) {
      status.value = CameraPlaybackStatus.paused;
      notifyListeners();
    }
  }

  Future<void> resume() => start();

  Future<void> disposeSession() => _disposing ??= _disposeSession();

  Future<void> _disposeSession() async {
    _disposed = true;
    ++_generation;
    _retryTimer?.cancel();
    _stallTimer?.cancel();
    _progressTimer?.cancel();
    await _errorSubscription?.cancel();
    await _playingSubscription?.cancel();
    await _positionSubscription?.cancel();
    final player = _player;
    _player = null;
    _videoController = null;
    if (player != null) await _closePlayer(player);
    final closing = _closing;
    if (closing != null) await closing;
    status.value = CameraPlaybackStatus.idle;
    notifyListeners();
    status.dispose();
    error.dispose();
    firstFrameRendered.dispose();
    dispose();
  }

  Uri get _streamUri {
    final stream = camera.playbackStream(useMainStream: useMainStream);
    return RtspStreamUri.build(
      host: stream.host ?? camera.host,
      port: stream.port ?? camera.effectivePort(defaultPort),
      path: stream.path,
      username: camera.username,
      password: password,
    );
  }

  void _markFailure(String message, {bool retry = true}) {
    ++_generation;
    final oldPlayer = _player;
    _stallTimer?.cancel();
    _progressTimer?.cancel();
    _player = null;
    _videoController = null;
    firstFrameRendered.value = false;
    _errorSubscription?.cancel();
    _playingSubscription?.cancel();
    _positionSubscription?.cancel();
    _errorSubscription = null;
    _playingSubscription = null;
    _positionSubscription = null;
    if (oldPlayer != null) unawaited(_closePlayer(oldPlayer));
    _failures++;
    error.value = message;
    status.value = retryEnabled && retry
        ? CameraPlaybackStatus.reconnecting
        : CameraPlaybackStatus.error;
    if (retryEnabled && retry) _scheduleRetry();
    notifyListeners();
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    _nextRetryDelay = _retryDelay();
    _retryTimer = Timer(_nextRetryDelay!, () {
      if (!_disposed) {
        _totalReconnectAttempts++;
        start();
      }
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

  Future<void> _closePlayer(Player player) {
    final previous = _closing;
    final closing = () async {
      if (previous != null) await previous;
      await _disposePlayer(player);
    }();
    _closing = closing;
    return closing;
  }
}
