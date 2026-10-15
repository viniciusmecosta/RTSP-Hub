import 'package:flutter_test/flutter_test.dart';
import 'package:rtsp_hub/features/monitor/domain/reconnect_policy.dart';

void main() {
  test(
    'uses increasing delays with bounded jitter and a 30 second ceiling',
    () {
      final first = ReconnectPolicy.delayFor(1);
      final second = ReconnectPolicy.delayFor(2);
      final firstWithJitter = ReconnectPolicy.delayFor(1, jitterFactor: 1);
      final capped = ReconnectPolicy.delayFor(20, jitterFactor: 1);

      expect(first.inSeconds, 2);
      expect(second, greaterThan(first));
      expect(firstWithJitter, greaterThan(first));
      expect(capped.inSeconds, 30);
      expect(ReconnectPolicy.delayFor(1, jitterFactor: -1), first);
    },
  );
}
