import 'package:flutter_test/flutter_test.dart';
import 'package:rtsp_view/features/discovery/domain/rtsp_channel_candidates.dart';

void main() {
  group('RtspChannelCandidates', () {
    test(
      'creates distinct main and secondary paths for each recorder channel',
      () {
        expect(RtspChannelCandidates.mainForChannel(4), [
          '/Streaming/Channels/401',
          '/cam/realmonitor?channel=4&subtype=0',
        ]);
        expect(RtspChannelCandidates.subForChannel(4), [
          '/Streaming/Channels/402',
          '/cam/realmonitor?channel=4&subtype=1',
        ]);
      },
    );

    test('tries a saved camera path and generic endpoints on channel one', () {
      final candidates = RtspChannelCandidates.mainForChannel(
        1,
        preferredPath: '/custom/live',
      );

      expect(candidates.first, '/custom/live');
      expect(candidates, contains('/Streaming/Channels/101'));
      expect(candidates, contains('/live/ch00_0'));
      expect(candidates.toSet(), hasLength(candidates.length));
    });

    test('rejects channel values outside the supported range', () {
      expect(RtspChannelCandidates.mainForChannel(0), isEmpty);
      expect(RtspChannelCandidates.subForChannel(256), isEmpty);
    });
  });
}
