import 'package:flutter_test/flutter_test.dart';
import 'package:rtsp_view/features/discovery/data/onvif_discovery_service.dart';
import 'package:rtsp_view/features/discovery/domain/rtsp_channel_candidates.dart';

OnvifProfile _profile(
  String token,
  String uri, {
  String? source = 'VideoSource_1',
  int width = 1920,
  int height = 1080,
}) => OnvifProfile(
  token: token,
  name: token,
  sourceToken: source,
  streamUri: Uri.parse(uri),
  width: width,
  height: height,
  framesPerSecond: 15,
  encoding: 'H264',
);

void main() {
  test('reduz 16 perfis de uma câmera a principal e subfluxo', () {
    final profiles = [
      for (var i = 0; i < 8; i++)
        _profile('main$i', 'rtsp://10.0.0.2/Streaming/Channels/101'),
      for (var i = 0; i < 8; i++)
        _profile(
          'sub$i',
          'rtsp://10.0.0.2/Streaming/Channels/102',
          width: 640,
          height: 360,
        ),
    ];

    final pairs = OnvifStreamPair.group(profiles);

    expect(pairs, hasLength(1));
    expect(pairs.single.main.width, 1920);
    expect(pairs.single.sub?.width, 640);
  });

  test('ignora perfil secundário com a mesma resolução do principal', () {
    final pairs = OnvifStreamPair.group([
      _profile('a', 'rtsp://10.0.0.2/a'),
      _profile('b', 'rtsp://10.0.0.2/b'),
    ]);

    expect(pairs.single.sub, isNull);
  });

  test('mantém fontes de vídeo distintas de um NVR', () {
    final pairs = OnvifStreamPair.group([
      _profile('a', 'rtsp://nvr/101', source: 'VS1'),
      _profile('b', 'rtsp://nvr/102', source: 'VS1', width: 640, height: 360),
      _profile('c', 'rtsp://nvr/201', source: 'VS2'),
    ]);

    expect(pairs, hasLength(2));
  });

  test('separa canais ONVIF sem token quando o URI identifica o canal', () {
    final pairs = OnvifStreamPair.group([
      _profile('a', 'rtsp://nvr/Streaming/Channels/101', source: null),
      _profile(
        'b',
        'rtsp://nvr/Streaming/Channels/102',
        source: null,
        width: 640,
        height: 360,
      ),
      _profile('c', 'rtsp://nvr/Streaming/Channels/201', source: null),
      _profile(
        'd',
        'rtsp://nvr/Streaming/Channels/202',
        source: null,
        width: 640,
        height: 360,
      ),
    ]);

    expect(pairs, hasLength(2));
    expect(pairs[0].sub?.streamUri.path, '/Streaming/Channels/102');
    expect(pairs[1].sub?.streamUri.path, '/Streaming/Channels/202');
  });

  test('só compara resoluções conhecidas dos fluxos', () {
    expect(StreamSignature.resolution('640×360 · H264'), '640x360');
    expect(
      StreamSignature.sameKnownResolution('Vídeo detectado', 'H264'),
      isFalse,
    );
    expect(
      StreamSignature.sameKnownResolution('1920×1080', '640×360'),
      isFalse,
    );
    expect(
      StreamSignature.sameKnownResolution(
        '1920×1080 · H264',
        '1920×1080 · H265',
      ),
      isTrue,
    );
  });
}
