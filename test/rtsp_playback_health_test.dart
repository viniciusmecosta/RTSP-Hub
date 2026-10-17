import 'package:flutter_test/flutter_test.dart';
import 'package:rtsp_hub/features/monitor/domain/rtsp_playback_health.dart';

Duration _at(int seconds) => Duration(seconds: seconds);

void main() {
  test('detects interrupted live streams even if position never advanced', () {
    final health = RtspPlaybackHealth()..begin(Duration.zero);
    expect(
      health.isStalled(
        _at(5),
        playing: true,
        buffering: true,
        inputBytesPerSecond: 0,
      ),
      isFalse,
    );
    expect(
      health.isStalled(
        _at(15),
        playing: true,
        buffering: true,
        inputBytesPerSecond: 0,
      ),
      isFalse,
    );
    expect(
      health.isStalled(
        _at(25),
        playing: true,
        buffering: true,
        inputBytesPerSecond: 0,
      ),
      isTrue,
    );
  });

  test('static pictures with advancing frame timestamps remain healthy', () {
    final health = RtspPlaybackHealth()..begin(Duration.zero);
    for (var second = 5; second <= 300; second += 5) {
      expect(
        health.isStalled(
          _at(second),
          playing: true,
          buffering: false,
          videoPts: second.toDouble(),
          inputBytesPerSecond: 10000,
        ),
        isFalse,
      );
    }
  });

  test('detects a decoder that stops advancing after valid timestamps', () {
    final health = RtspPlaybackHealth()..begin(Duration.zero);
    health.isStalled(
      _at(5),
      playing: true,
      buffering: false,
      videoPts: 1,
      inputBytesPerSecond: 10000,
    );
    health.isStalled(
      _at(10),
      playing: true,
      buffering: false,
      videoPts: 2,
      inputBytesPerSecond: 10000,
    );
    expect(
      health.isStalled(
        _at(35),
        playing: true,
        buffering: false,
        videoPts: 2,
        inputBytesPerSecond: 10000,
      ),
      isTrue,
    );
  });

  test(
    'unknown or constant timestamps with arriving data do not force reconnects',
    () {
      final health = RtspPlaybackHealth()..begin(Duration.zero);
      for (var second = 5; second <= 300; second += 5) {
        expect(
          health.isStalled(
            _at(second),
            playing: true,
            buffering: false,
            videoPts: 0,
            inputBytesPerSecond: 10000,
          ),
          isFalse,
        );
      }
    },
  );

  test('transient buffering and network recovery reset suspicion', () {
    final health = RtspPlaybackHealth()..begin(Duration.zero);
    health.isStalled(
      _at(5),
      playing: true,
      buffering: true,
      inputBytesPerSecond: 0,
    );
    health.positionChanged(_at(12), _at(12));
    expect(
      health.isStalled(
        _at(15),
        playing: true,
        buffering: false,
        inputBytesPerSecond: 10000,
      ),
      isFalse,
    );
    expect(
      health.isStalled(
        _at(30),
        playing: true,
        buffering: false,
        inputBytesPerSecond: 0,
      ),
      isFalse,
    );
    expect(
      health.isStalled(
        _at(45),
        playing: true,
        buffering: false,
        inputBytesPerSecond: 0,
      ),
      isFalse,
    );
    expect(
      health.isStalled(
        _at(55),
        playing: true,
        buffering: false,
        inputBytesPerSecond: 0,
      ),
      isTrue,
    );
  });

  test('uses sparse probes and resets evidence on restart', () {
    final health = RtspPlaybackHealth()..begin(Duration.zero);
    health.positionChanged(_at(4), _at(4));
    expect(health.needsProbe(_at(9)), isFalse);
    expect(health.needsProbe(_at(14)), isTrue);
    health.begin(_at(15));
    expect(health.needsProbe(_at(16)), isFalse);
    expect(health.isStalled(_at(16), playing: true, buffering: false), isFalse);
    expect(
      health.isStalled(
        _at(17),
        playing: true,
        buffering: false,
        endOfStream: true,
      ),
      isTrue,
    );
  });
}
