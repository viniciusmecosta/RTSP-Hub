import 'dart:async';

class RtspConnectionCoordinator {
  RtspConnectionCoordinator({
    int maxConcurrent = 2,
    Duration spacing = const Duration(milliseconds: 180),
    this.preparationTimeout = const Duration(seconds: 2),
  }) : _maxConcurrent = maxConcurrent.clamp(1, 8),
       _spacing = spacing < Duration.zero ? Duration.zero : spacing;

  final _queue = <RtspConnectionTicket>[];
  final _leases = <RtspConnectionLease>{};
  final Duration preparationTimeout;
  final _clock = Stopwatch()..start();
  int _maxConcurrent;
  Duration _spacing;
  Duration? _lastStart;
  Timer? _timer;
  int _active = 0;
  bool _disposed = false;

  int get activeConnections => _active;
  int get queuedConnections => _queue.length;

  void configure({required int maxConcurrent, required Duration spacing}) {
    _maxConcurrent = maxConcurrent.clamp(1, 8);
    _spacing = spacing < Duration.zero ? Duration.zero : spacing;
    _timer?.cancel();
    _timer = null;
    _drain();
  }

  RtspConnectionTicket request({int priority = 0}) {
    final ticket = RtspConnectionTicket._(this, priority);
    if (_disposed) {
      ticket._result.complete(null);
    } else {
      _queue.add(ticket);
      _drain();
    }
    return ticket;
  }

  void _drain() {
    if (_disposed ||
        _timer != null ||
        _active >= _maxConcurrent ||
        _queue.isEmpty) {
      return;
    }
    final last = _lastStart;
    final remaining = last == null
        ? Duration.zero
        : _spacing - (_clock.elapsed - last);
    if (remaining > Duration.zero) {
      _timer = Timer(remaining, () {
        _timer = null;
        _drain();
      });
      return;
    }
    var next = 0;
    for (var i = 1; i < _queue.length; i++) {
      if (_queue[i].priority > _queue[next].priority) next = i;
    }
    final ticket = _queue.removeAt(next);
    _active++;
    _lastStart = _clock.elapsed;
    late final RtspConnectionLease lease;
    lease = RtspConnectionLease._(() {
      _leases.remove(lease);
      _active--;
      _drain();
    }, preparationTimeout);
    _leases.add(lease);
    ticket._result.complete(lease);
    _drain();
  }

  void _cancel(RtspConnectionTicket ticket) {
    if (_queue.remove(ticket)) {
      ticket._result.complete(null);
      _drain();
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _timer?.cancel();
    for (final ticket in _queue) {
      ticket._result.complete(null);
    }
    _queue.clear();
    for (final lease in _leases.toList()) {
      lease.release();
    }
  }
}

class RtspConnectionTicket {
  RtspConnectionTicket._(this._coordinator, this.priority);
  final RtspConnectionCoordinator _coordinator;
  final int priority;
  final _result = Completer<RtspConnectionLease?>();
  Future<RtspConnectionLease?> get ready => _result.future;
  void cancel() => _coordinator._cancel(this);
}

class RtspConnectionLease {
  RtspConnectionLease._(this._onRelease, Duration timeout) {
    _deadline = Timer(timeout, release);
  }
  final void Function() _onRelease;
  Timer? _deadline;
  bool _released = false;

  void release() {
    if (_released) return;
    _released = true;
    _deadline?.cancel();
    _onRelease();
  }
}
