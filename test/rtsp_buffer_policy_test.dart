import 'package:flutter_test/flutter_test.dart';
import 'package:rtsp_hub/features/monitor/domain/rtsp_buffer_policy.dart';

void main() {
  test('light and balanced have distinct effective cache limits', () {
    for (final main in [false, true]) {
      expect(
        RtspBufferPolicy.bytesFor(targetMilliseconds: 180, mainStream: main),
        lessThan(
          RtspBufferPolicy.bytesFor(targetMilliseconds: 400, mainStream: main),
        ),
      );
    }
  });

  test('reserves a bounded network buffer for each active stream', () {
    final light = RtspBufferPolicy.bytesFor(
      targetMilliseconds: 180,
      mainStream: false,
    );
    final focused = RtspBufferPolicy.bytesFor(
      targetMilliseconds: 800,
      mainStream: true,
    );

    expect(light, 180 * 1024);
    expect(focused, 1600 * 1024);
    expect(
      RtspBufferPolicy.bytesFor(targetMilliseconds: 99999, mainStream: true),
      lessThanOrEqualTo(4 * 1024 * 1024),
    );
  });
}
