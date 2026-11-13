import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

class TransferCodec {
  static const prefix = 'RTH1:';
  static const maxDecodedBytes = 64 * 1024 * 1024;
  static const maxCodeCharacters = 90 * 1024 * 1024;
  static const maxQrCharacters = 1800;

  static String encode(String json) {
    final compact = jsonEncode(jsonDecode(json));
    final bytes = utf8.encode(compact);
    if (bytes.length > maxDecodedBytes) {
      throw const FormatException('Configuração muito grande.');
    }
    final checksum = sha256.convert(bytes).toString().substring(0, 12);
    return '$prefix${base64Url.encode(ZLibEncoder(level: 9).convert(bytes)).replaceAll('=', '')}.$checksum';
  }

  static String decode(String source) {
    source = source.trim();
    if (source.length > maxCodeCharacters) {
      throw const FormatException('Código muito grande.');
    }
    if (!source.startsWith(prefix)) {
      if (source.startsWith('RTH')) {
        throw const FormatException('Versão de código não suportada.');
      }
      return source;
    }
    try {
      final parts = source.substring(prefix.length).split('.');
      if (parts.length != 2 || !RegExp(r'^[a-f0-9]{12}$').hasMatch(parts[1])) {
        throw const FormatException();
      }
      final bytes = base64Url.decode(base64Url.normalize(parts[0]));
      final target = _LimitedBytes(maxDecodedBytes);
      final decoder = ZLibDecoder().startChunkedConversion(
        ByteConversionSink.from(target),
      );
      for (var offset = 0; offset < bytes.length; offset += 1024) {
        decoder.add(
          bytes.sublist(offset, (offset + 1024).clamp(0, bytes.length)),
        );
      }
      decoder.close();
      final result = target.bytes;
      if (sha256.convert(result).toString().substring(0, 12) != parts[1]) {
        throw const FormatException();
      }
      final decoded = utf8.decode(result);
      jsonDecode(decoded);
      return decoded;
    } on Object {
      throw const FormatException(
        'Código inválido, incompleto ou muito grande.',
      );
    }
  }
}

class _LimitedBytes implements Sink<List<int>> {
  _LimitedBytes(this.limit);
  final int limit;
  final _builder = BytesBuilder(copy: true);
  Uint8List get bytes => _builder.takeBytes();
  @override
  void add(List<int> data) {
    if (_builder.length + data.length > limit) {
      throw const FormatException('Limite de descompressão excedido.');
    }
    _builder.add(data);
  }

  @override
  void close() {}
}
