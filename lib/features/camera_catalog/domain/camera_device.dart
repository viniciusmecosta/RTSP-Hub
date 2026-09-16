class CameraDevice {
  const CameraDevice({
    required this.id,
    required this.name,
    required this.host,
    required this.mainPath,
    this.port,
    this.username = '',
    this.subPath = '',
  });

  final String id;
  final String name;
  final String host;
  final int? port;
  final String username;
  final String mainPath;
  final String subPath;

  int effectivePort(int defaultPort) => port ?? defaultPort;

  CameraDevice copyWith({
    String? name,
    String? host,
    int? port,
    bool clearPort = false,
    String? username,
    String? mainPath,
    String? subPath,
  }) {
    return CameraDevice(
      id: id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: clearPort ? null : port ?? this.port,
      username: username ?? this.username,
      mainPath: mainPath ?? this.mainPath,
      subPath: subPath ?? this.subPath,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'host': host,
    'port': port,
    'username': username,
    'mainPath': mainPath,
    'subPath': subPath,
  };

  factory CameraDevice.fromJson(Map<String, Object?> json) {
    return CameraDevice(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      host: json['host'] as String,
      port: (json['port'] as num?)?.toInt(),
      username: json['username'] as String? ?? '',
      mainPath: json['mainPath'] as String? ?? '/Streaming/Channels/101',
      subPath: json['subPath'] as String? ?? '',
    );
  }
}
