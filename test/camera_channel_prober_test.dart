import 'package:flutter_test/flutter_test.dart';
import 'package:rtsp_hub/features/camera_catalog/application/camera_channel_prober.dart';
import 'package:rtsp_hub/features/discovery/data/onvif_discovery_service.dart';

class _Onvif extends OnvifDiscoveryService {
  _Onvif(this.device);
  final OnvifDevice? device;

  @override
  Future<OnvifDevice?> loadProfiles(
    OnvifProbeDevice device, {
    required String username,
    required String password,
    Duration timeout = const Duration(seconds: 3),
    bool Function()? isCancelled,
  }) async => this.device;
}

Future<List<dynamic>> _find(
  CameraChannelProber prober, {
  bool recorder = false,
}) => prober.findChannels(
  host: '10.0.0.2',
  port: 554,
  username: '',
  password: '',
  defaultPath: '/default',
  searchRecorderChannels: recorder,
  isCancelled: () => false,
  onProgress: (_) {},
);

void main() {
  test('keeps ONVIF host and distinct stream ports', () async {
    final prober = CameraChannelProber(
      onvif: _Onvif(
        OnvifDevice(
          host: '10.0.0.2',
          deviceServiceUri: Uri.parse('http://10.0.0.2/onvif'),
          name: null,
          profiles: [
            for (final sub in [false, true])
              OnvifProfile(
                token: '$sub',
                name: '$sub',
                sourceToken: 'source-3',
                streamUri: Uri.parse(
                  sub
                      ? 'rtsp://10.0.0.3:10554/sub?x=1'
                      : 'rtsp://10.0.0.3:8554/main',
                ),
                width: sub ? 640 : 1920,
                height: sub ? 360 : 1080,
                framesPerSecond: 15,
                encoding: 'H264',
              ),
          ],
        ),
      ),
    );
    final found = await _find(prober);
    expect(found.single.host, '10.0.0.3');
    expect(found.single.port, 8554);
    expect(found.single.subPort, 10554);
    expect(found.single.number, 3);
    expect(found.single.toChannel().sub!.path, '/sub?x=1');
    await prober.dispose();
  });

  test('uses RTSP port 554 when ONVIF does not announce one', () async {
    final prober = CameraChannelProber(
      onvif: _Onvif(
        OnvifDevice(
          host: '10.0.0.2',
          deviceServiceUri: Uri.parse('http://10.0.0.2/onvif'),
          name: null,
          profiles: [
            OnvifProfile(
              token: '1',
              name: 'Main',
              sourceToken: null,
              streamUri: Uri.parse('rtsp://10.0.0.2/main'),
              width: 1920,
              height: 1080,
              framesPerSecond: 15,
              encoding: 'H264',
            ),
          ],
        ),
      ),
    );
    final found = await _find(prober);
    expect(found.single.port, 554);
    await prober.dispose();
  });

  test(
    'keeps looking after empty recorder channels without inventing streams',
    () async {
      final tested = <String>[];
      final prober = CameraChannelProber(
        onvif: _Onvif(null),
        qualityProbe:
            ({
              required host,
              required port,
              required username,
              required password,
              required path,
              required isCancelled,
            }) async {
              tested.add(path);
              return switch (path) {
                '/Streaming/Channels/101' ||
                '/Streaming/Channels/301' ||
                '/Streaming/Channels/801' => '1920×1080',
                '/Streaming/Channels/102' ||
                '/Streaming/Channels/302' ||
                '/Streaming/Channels/802' => '640×360',
                _ => null,
              };
            },
      );
      final found = await _find(prober, recorder: true);
      expect(found.map((c) => c.number), [1, 3, 8]);
      expect(tested, contains('/Streaming/Channels/1601'));
      expect(found.last.toChannel().sub!.path, '/Streaming/Channels/802');
      await prober.dispose();
    },
  );
}
