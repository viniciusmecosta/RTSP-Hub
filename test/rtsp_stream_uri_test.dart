import 'package:flutter_test/flutter_test.dart';
import 'package:rtsp_view/features/monitor/domain/rtsp_stream_uri.dart';

void main() {
  test('encodes reserved characters in credentials without changing query', () {
    final uri = RtspStreamUri.build(
      host: '192.168.1.5',
      port: 554,
      path: '/1/1?transmode=unicast&profile=van',
      username: 'admin@local',
      password: r'p@[ss]:%word',
    );

    expect(
      uri.toString(),
      'rtsp://admin%40local:p%40%5Bss%5D%3A%25word@192.168.1.5:554/1/1?transmode=unicast&profile=van',
    );
  });

  test('builds stream without credentials', () {
    final uri = RtspStreamUri.build(
      host: 'camera.local',
      port: 8554,
      path: 'live/main',
      username: '',
    );

    expect(uri.toString(), 'rtsp://camera.local:8554/live/main');
  });

  test('accepts spaces, unicode and every reserved credential separator', () {
    final uri = RtspStreamUri.build(
      host: '192.168.1.5',
      port: 554,
      path: '/live',
      username: 'usuário local',
      password: r'P@ss word:/?#[]%&=+',
    );

    expect(uri.host, '192.168.1.5');
    expect(uri.path, '/live');
    expect(uri.toString(), isNot(contains('P@ss word')));
    expect(Uri.parse(uri.toString()).host, '192.168.1.5');
  });
}
