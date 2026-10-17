import 'camera_field_validation.dart';

class CameraStream {
  const CameraStream({
    required this.path,
    this.host,
    this.port,
    this.quality = '',
  });

  final String path;
  final String? host;
  final int? port;
  final String quality;

  bool get isValid =>
      CameraFieldValidation.pathError(path) == null &&
      (host == null || CameraFieldValidation.hostError(host!) == null) &&
      (port == null || (port! >= 1 && port! <= 65535)) &&
      quality.length <= 256;

  Map<String, Object?> toJson() => {
    'path': path,
    if (host != null) 'host': host,
    if (port != null) 'port': port,
    'quality': quality,
  };

  factory CameraStream.fromJson(Map<String, Object?> json) {
    final stream = CameraStream(
      path: json['path'] as String,
      host: json['host'] as String?,
      port: (json['port'] as num?)?.toInt(),
      quality: json['quality'] as String? ?? '',
    );
    if (!stream.isValid) {
      throw const FormatException('Perfil de vídeo inválido.');
    }
    return stream;
  }
}

class CameraChannel {
  const CameraChannel({
    required this.id,
    required this.label,
    required this.main,
    this.sub,
  });

  final String id;
  final String label;
  final CameraStream main;
  final CameraStream? sub;

  bool get isValid =>
      id.isNotEmpty &&
      id.length <= 256 &&
      label.isNotEmpty &&
      label.length <= 80 &&
      main.isValid &&
      (sub == null || sub!.isValid);

  CameraStream stream({required bool useMainStream}) =>
      useMainStream ? main : sub ?? main;

  bool containsPath(String path) => main.path == path || sub?.path == path;

  Map<String, Object?> toJson() => {
    'id': id,
    'label': label,
    'main': main.toJson(),
    if (sub != null) 'sub': sub!.toJson(),
  };

  factory CameraChannel.fromJson(Map<String, Object?> json) {
    final channel = CameraChannel(
      id: json['id'] as String,
      label: json['label'] as String,
      main: CameraStream.fromJson(
        Map<String, Object?>.from(json['main'] as Map),
      ),
      sub: json['sub'] == null
          ? null
          : CameraStream.fromJson(
              Map<String, Object?>.from(json['sub'] as Map),
            ),
    );
    if (!channel.isValid) throw const FormatException('Canal inválido.');
    return channel;
  }

  static List<CameraChannel> migrate({
    required String mainPath,
    required String subPath,
    required List<String> savedPaths,
  }) {
    final paths = <String>{
      if (mainPath.isNotEmpty) mainPath,
      if (subPath.isNotEmpty) subPath,
      ...savedPaths.where((p) => p.isNotEmpty),
    };
    final result = <CameraChannel>[];
    final consumed = <String>{};
    if (mainPath.isNotEmpty) {
      result.add(
        CameraChannel(
          id: mainPath,
          label: _label(mainPath),
          main: CameraStream(path: mainPath),
          sub: subPath.isEmpty ? null : CameraStream(path: subPath),
        ),
      );
      consumed.addAll([mainPath, subPath]);
    }
    for (final path in paths) {
      if (consumed.contains(path)) continue;
      final identity = _identity(path);
      final related = identity == null
          ? <String>[path]
          : paths
                .where(
                  (p) =>
                      !consumed.contains(p) && _identity(p)?.$1 == identity.$1,
                )
                .toList();
      final primary =
          related.where((p) => _identity(p)?.$2 == 0).firstOrNull ?? path;
      final secondary = related
          .where((p) => p != primary && _identity(p)?.$2 == 1)
          .firstOrNull;
      result.add(
        CameraChannel(
          id: primary,
          label: _label(primary),
          main: CameraStream(path: primary),
          sub: secondary == null ? null : CameraStream(path: secondary),
        ),
      );
      consumed.add(primary);
      if (secondary != null) consumed.add(secondary);
    }
    return result;
  }

  static String _label(String path) {
    final identity = _identity(path);
    return identity == null ? path : 'Canal ${identity.$1}';
  }

  static (String, int)? _identity(String path) {
    final uri = Uri.tryParse(path);
    if (uri == null) return null;
    final match = RegExp(
      r'/Streaming/Channels/(\d+)$',
      caseSensitive: false,
    ).firstMatch(uri.path);
    if (match != null) {
      final value = int.tryParse(match.group(1)!);
      if (value != null &&
          value >= 100 &&
          (value % 100 == 1 || value % 100 == 2)) {
        return ('${value ~/ 100}', value % 100 - 1);
      }
    }
    final channel = uri.queryParameters['channel'];
    final subtype = int.tryParse(uri.queryParameters['subtype'] ?? '');
    if (channel != null && (subtype == 0 || subtype == 1)) {
      return (channel, subtype!);
    }
    return null;
  }
}
