import 'package:flutter_test/flutter_test.dart';
import 'package:rtsp_view/features/discovery/data/onvif_discovery_service.dart';

void main() {
  test('extracts the device endpoint and friendly name from a probe match', () {
    const response = '''
<s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope">
  <s:Body>
    <d:ProbeMatches xmlns:d="http://schemas.xmlsoap.org/ws/2005/04/discovery">
      <d:ProbeMatch>
        <d:XAddrs>http://192.168.1.20/onvif/device_service</d:XAddrs>
        <d:Scopes>onvif://www.onvif.org/name/Portaria%20NVR</d:Scopes>
      </d:ProbeMatch>
    </d:ProbeMatches>
  </s:Body>
</s:Envelope>
''';

    final device = OnvifDiscoveryService.parseProbeResponse(
      response,
      sourceAddress: '192.168.1.20',
    );

    expect(device?.sourceAddress, '192.168.1.20');
    expect(device?.deviceServiceUri.path, '/onvif/device_service');
    expect(device?.name, 'Portaria NVR');
  });

  test('ignores malformed and non-http discovery responses', () {
    expect(
      OnvifDiscoveryService.parseProbeResponse(
        '<Envelope><XAddrs>rtsp://192.168.1.20/live</XAddrs></Envelope>',
        sourceAddress: '192.168.1.20',
      ),
      isNull,
    );
    expect(
      OnvifDiscoveryService.parseProbeResponse(
        '<Envelope>',
        sourceAddress: '192.168.1.20',
      ),
      isNull,
    );
  });
}
