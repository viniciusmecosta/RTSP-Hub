import 'package:flutter_test/flutter_test.dart';
import 'package:rtsp_hub/features/discovery/data/local_network_scanner.dart';
import 'package:rtsp_hub/features/discovery/domain/rtsp_channel_candidates.dart';

void main() {
  final scanner = LocalNetworkScanner();

  test('scans the entire requested /22 range', () {
    final hosts = scanner.hostsInRange('192.168.14.0/22');

    expect(hosts, hasLength(1022));
    expect(hosts.first, '192.168.12.1');
    expect(hosts.last, '192.168.15.254');
  });

  test('accepts a narrow network and excludes network and broadcast hosts', () {
    final hosts = scanner.hostsInRange('10.0.0.8/30');

    expect(hosts, ['10.0.0.9', '10.0.0.10']);
  });

  test('rejects malformed and unsupported network ranges', () {
    expect(() => scanner.hostsInRange('not-a-network'), throwsFormatException);
    expect(() => scanner.hostsInRange('10.0.0.0/31'), throwsFormatException);
    expect(
      () => scanner.hostsInRange('192.168.14.0/16'),
      throwsFormatException,
    );
    expect(
      () => scanner.hostsInRange('192.168.14.0/21'),
      throwsFormatException,
    );
    expect(() => scanner.hostsInRange('2001:db8::/64'), throwsFormatException);
  });

  test('creates manufacturer paths for a selected recorder channel', () {
    final paths = RtspChannelCandidates.forChannel(3);

    expect(paths, contains('/Streaming/Channels/301'));
    expect(paths, contains('/cam/realmonitor?channel=3&subtype=0'));
    expect(paths, contains('/media/video1'));
  });

  test('rejects channel numbers outside the supported range', () {
    expect(RtspChannelCandidates.forChannel(0), isEmpty);
    expect(RtspChannelCandidates.forChannel(256), isEmpty);
  });
}
