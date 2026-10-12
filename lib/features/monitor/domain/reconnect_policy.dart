import 'dart:math';

class ReconnectPolicy {
  static Duration delayFor(int consecutiveFailures, {double jitterFactor = 0}) {
    final attempts = consecutiveFailures.clamp(1, 1000);
    final base = min(30.0, 2 * pow(1.7, attempts - 1)).toDouble();
    final jitterLimit = min(1.5, base * 0.2);
    final jitter = jitterLimit * jitterFactor.clamp(0, 1);
    return Duration(milliseconds: (min(30.0, base + jitter) * 1000).round());
  }
}
