import 'dart:async';

class DiscoveryCancelled implements Exception {
  const DiscoveryCancelled();
}

class DiscoveryCancellation {
  final _cancelled = Completer<void>();
  bool get isCancelled => _cancelled.isCompleted;

  void cancel() {
    if (!isCancelled) _cancelled.complete();
  }

  Future<T> bind<T>(Future<T> operation) {
    if (isCancelled) {
      operation.ignore();
      return Future.error(const DiscoveryCancelled());
    }
    return Future.any([
      operation,
      _cancelled.future.then<T>((_) => throw const DiscoveryCancelled()),
    ]);
  }
}
