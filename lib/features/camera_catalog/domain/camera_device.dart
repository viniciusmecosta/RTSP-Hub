import 'camera_channel.dart';

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
    this.selectedPath = '',
    this.channels = const [],
    this.selectedChannelId = '',
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
  final String selectedPath;
  final List<CameraChannel> channels;
  final String selectedChannelId;

  List<CameraChannel> get availableChannels => channels.isNotEmpty
      ? channels
      : CameraChannel.migrate(
          mainPath: mainPath,
          subPath: subPath,
          savedPaths: savedPaths,
        );

  CameraChannel? get activeChannel {
    final items = availableChannels;
    return items.where((c) => c.id == selectedChannelId).firstOrNull ??
        items
            .where(
              (c) => selectedPath.isNotEmpty && c.containsPath(selectedPath),
            )
            .firstOrNull ??
        items.firstOrNull;
  }

  CameraStream playbackStream({required bool useMainStream}) =>
      activeChannel?.stream(useMainStream: useMainStream) ??
      CameraStream(path: useMainStream || subPath.isEmpty ? mainPath : subPath);

  int effectivePort(int defaultPort) => port ?? defaultPort;

  CameraDevice resolved({
    required int defaultPort,
    required String defaultUser,
    required String defaultPath,
    String defaultSubPath = '',
  }) => copyWith(
    port: effectivePort(defaultPort),
    username: username.trim().isEmpty ? defaultUser : username,
    mainPath: mainPath.trim().isEmpty ? defaultPath : mainPath,
    subPath: subPath.trim().isEmpty ? defaultSubPath : subPath,
    useGlobalCredentials: false,
  );

  String playbackPath({required bool useMainStream}) =>
      playbackStream(useMainStream: useMainStream).path;

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
    String? selectedPath,
    List<CameraChannel>? channels,
    String? selectedChannelId,
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
      selectedPath: selectedPath ?? this.selectedPath,
      channels: channels ?? this.channels,
      selectedChannelId: selectedChannelId ?? this.selectedChannelId,
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
    'selectedPath': selectedPath,
    'channels': channels.map((c) => c.toJson()).toList(),
    'selectedChannelId': selectedChannelId,
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
      selectedPath: json['selectedPath'] as String? ?? '',
      channels: (json['channels'] as List? ?? const [])
          .map(
            (item) =>
                CameraChannel.fromJson(Map<String, Object?>.from(item as Map)),
          )
          .toList(growable: false),
      selectedChannelId: json['selectedChannelId'] as String? ?? '',
    );
  }
}
