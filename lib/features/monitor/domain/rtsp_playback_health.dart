class RtspPlaybackHealth {
  RtspPlaybackHealth({this.stallTimeout = const Duration(seconds: 20)});

  final Duration stallTimeout;
  Duration? _lastProgress;
  Duration? _networkIdleSince;
  Duration? _interruptedSince;
  Duration _position = Duration.zero;
  double? _videoPts;
  bool _videoAdvanced = false;

  void begin(Duration now) {
    _lastProgress = now;
    _networkIdleSince = null;
    _interruptedSince = null;
    _position = Duration.zero;
    _videoPts = null;
    _videoAdvanced = false;
  }

  void positionChanged(Duration position, Duration now) {
    if (position != _position && position >= Duration.zero) {
      _lastProgress = now;
    }
    _position = position;
  }

  bool needsProbe(Duration now) =>
      _lastProgress != null &&
      now - _lastProgress! >= const Duration(seconds: 10);

  bool isStalled(
    Duration now, {
    required bool playing,
    required bool buffering,
    double? videoPts,
    double? inputBytesPerSecond,
    bool endOfStream = false,
  }) {
    if (_lastProgress == null) return false;
    if (endOfStream) return true;
    if (videoPts != null && videoPts.isFinite) {
      if (_videoPts != null && videoPts != _videoPts) {
        _lastProgress = now;
        _videoAdvanced = true;
      }
      _videoPts = videoPts;
    }
    if (inputBytesPerSecond != null && inputBytesPerSecond.isFinite) {
      if (inputBytesPerSecond > 0) {
        _networkIdleSince = null;
      } else {
        _networkIdleSince ??= now;
      }
    }
    if (!playing || buffering) {
      _interruptedSince ??= now;
    } else {
      _interruptedSince = null;
    }
    final interrupted = _interruptedSince;
    if (interrupted != null && now - interrupted >= stallTimeout) return true;
    if (now - _lastProgress! < stallTimeout) return false;
    final idle = _networkIdleSince;
    return (_videoAdvanced && videoPts != null) ||
        (idle != null && now - idle >= stallTimeout);
  }
}
