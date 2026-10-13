import 'package:flutter_test/flutter_test.dart';
import 'package:rtsp_view/features/monitor/domain/rtsp_buffer_policy.dart';

void main() {
  test('reserves a bounded network buffer for each active stream', () {
    final light = RtspBufferPolicy.bytesFor(
      targetMilliseconds: 180,
      mainStream: false,
    );
    final focused = RtspBufferPolicy.bytesFor(
      targetMilliseconds: 800,
      mainStream: true,
    );

    expect(light, 256 * 1024);
    expect(focused, 800 * 1024);
    expect(
      RtspBufferPolicy.bytesFor(targetMilliseconds: 99999, mainStream: true),
      lessThanOrEqualTo(4 * 1024 * 1024),
    );
  });
}
