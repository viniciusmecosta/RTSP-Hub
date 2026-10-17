import 'camera_channel.dart';

class FoundChannel {
  const FoundChannel({
    required this.number,
    required this.mainPath,
    required this.mainQuality,
    required this.subPath,
    required this.subQuality,
    this.host,
    this.port,
    this.subHost,
    this.subPort,
  });

  final String? host;
  final int? port;
  final String? subHost;
  final int? subPort;
  final int number;
  final String mainPath;
  final String mainQuality;
  final String? subPath;
  final String? subQuality;
  CameraChannel toChannel({bool subOnly = false}) => CameraChannel(
    id: mainPath,
    label: 'Canal $number',
    main: subOnly && subPath != null
        ? CameraStream(
            path: subPath!,
            host: subHost ?? host,
            port: subPort ?? port,
            quality: subQuality ?? '',
          )
        : CameraStream(
            path: mainPath,
            host: host,
            port: port,
            quality: mainQuality,
          ),
    sub: subOnly || subPath == null
        ? null
        : CameraStream(
            path: subPath!,
            host: subHost ?? host,
            port: subPort ?? port,
            quality: subQuality ?? '',
          ),
  );
}
