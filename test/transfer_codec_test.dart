import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:rtsp_hub/app/data/transfer_codec.dart';

void main() {
  test(
    'compact transport preserves Unicode and reduces repeated camera data',
    () {
      final json = jsonEncode({
        'version': 3,
        'cameras': List.generate(
          16,
          (i) => {
            'id': 'camera-$i',
            'name': 'Câmera $i',
            'host': '192.168.1.${i + 10}',
            'username': 'operador',
            'mainPath': '/Streaming/Channels/101',
            'subPath': '/Streaming/Channels/102',
          },
        ),
      });
      final code = TransferCodec.encode(json);
      expect(code.length, lessThan(json.length ~/ 2));
      expect(jsonDecode(TransferCodec.decode(code)), jsonDecode(json));
      expect(TransferCodec.decode('  $code  '), TransferCodec.decode(code));
    },
  );
  test('rejects unknown versions, corrupt data and non-JSON exports', () {
    for (final code in ['RTH2:test', 'RTH1:!', 'RTH1:eA', 'RTH1:']) {
      expect(() => TransferCodec.decode(code), throwsFormatException);
    }
    expect(() => TransferCodec.encode('not json'), throwsFormatException);
    expect(TransferCodec.decode('{"version":3}'), '{"version":3}');
    final code = TransferCodec.encode('{"version":3}');
    expect(
      () => TransferCodec.decode(code.substring(0, code.length - 3)),
      throwsFormatException,
    );
  });
}
