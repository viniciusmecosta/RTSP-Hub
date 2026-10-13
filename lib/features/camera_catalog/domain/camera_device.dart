class CameraDevice {
  const CameraDevice({
    required this.id,
    required this.name,
    required this.host,
    required this.mainPath,
    this.port,
    this.username = '',
    this.subPath = '',
    this.useGlobalCredentials = false,
    this.savedPaths = const [],
  });

  final String id;
  final String name;
  final String host;
  final int? port;
  final String username;
  final String mainPath;
  final String subPath;
  final bool useGlobalCredentials;
  final List<String> savedPaths;

  int effectivePort(int defaultPort) => port ?? defaultPort;

  CameraDevice copyWith({
    String? name,
    String? host,
    int? port,
    bool clearPort = false,
    String? username,
    String? mainPath,
    String? subPath,
    bool? useGlobalCredentials,
    List<String>? savedPaths,
  }) {
    return CameraDevice(
      id: id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: clearPort ? null : port ?? this.port,
      username: username ?? this.username,
      mainPath: mainPath ?? this.mainPath,
      subPath: subPath ?? this.subPath,
      useGlobalCredentials: useGlobalCredentials ?? this.useGlobalCredentials,
      savedPaths: savedPaths ?? this.savedPaths,
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
    'useGlobalCredentials': useGlobalCredentials,
    'savedPaths': savedPaths,
  };

  factory CameraDevice.fromJson(Map<String, Object?> json) {
    final rawPaths = json['savedPaths'];
    final savedPaths = rawPaths is List
        ? rawPaths.whereType<String>().toList(growable: false)
        : const <String>[];
    return CameraDevice(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      host: json['host'] as String,
      port: (json['port'] as num?)?.toInt(),
      username: json['username'] as String? ?? '',
      mainPath: json['mainPath'] as String? ?? '/Streaming/Channels/101',
      subPath: json['subPath'] as String? ?? '',
      useGlobalCredentials: json['useGlobalCredentials'] as bool? ?? false,
      savedPaths: savedPaths,
    );
  }
}
