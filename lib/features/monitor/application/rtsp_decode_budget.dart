import 'dart:async';

class RtspDecodeBudget {
  RtspDecodeBudget({required this.applySkipFrame});

  final Future<void> Function(String value) applySkipFrame;
  bool _background = false;
  bool? _applied;
  bool _disposed = false;
  int _revision = 0;
  Future<void>? _pending;

  Future<void> setBackground(bool background) {
    if (_disposed) return Future.value();
    if (_background == background &&
        (_pending != null || _applied == background)) {
      return _pending ?? Future.value();
    }
    _background = background;
    final revision = ++_revision;
    final operation = (_pending ?? Future<void>.value()).then((_) async {
      if (_disposed || revision != _revision || _applied == background) return;
      try {
        await applySkipFrame(
          background ? 'nonref' : 'default',
        ).timeout(const Duration(milliseconds: 750));
        if (!_disposed) _applied = background;
      } on Object {
        return;
      }
    });
    late final Future<void> tracked;
    tracked = operation.whenComplete(() {
      if (identical(_pending, tracked)) _pending = null;
    });
    _pending = tracked;
    return tracked;
  }

  void dispose() => _disposed = true;
}
