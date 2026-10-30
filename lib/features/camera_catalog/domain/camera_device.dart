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
    this.thumbnailCapturedAt,
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
  final DateTime? thumbnailCapturedAt;

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

  static int compareByHost(
    CameraDevice left,
    CameraDevice right, {
    int defaultPort = 554,
  }) {
    final hostComparison = compareHosts(left.host, right.host);
    if (hostComparison != 0) return hostComparison;
    final portComparison = left
        .effectivePort(defaultPort)
        .compareTo(right.effectivePort(defaultPort));
    if (portComparison != 0) return portComparison;
    final nameComparison = _compareNatural(left.name, right.name);
    if (nameComparison != 0) return nameComparison;
    final pathComparison = _compareNatural(left.mainPath, right.mainPath);
    if (pathComparison != 0) return pathComparison;
    return left.id.compareTo(right.id);
  }

  static int compareHosts(String left, String right) {
    final leftIpv4 = _parseIpv4(left);
    final rightIpv4 = _parseIpv4(right);
    if (leftIpv4 != null && rightIpv4 != null) {
      return leftIpv4.compareTo(rightIpv4);
    }
    if (leftIpv4 != null) return -1;
    if (rightIpv4 != null) return 1;
    return _compareNatural(left, right);
  }

  static int? _parseIpv4(String host) {
    final parts = host.trim().split('.');
    if (parts.length != 4) return null;
    var value = 0;
    for (final part in parts) {
      final octet = int.tryParse(part);
      if (octet == null || octet < 0 || octet > 255) return null;
      value = (value << 8) | octet;
    }
    return value;
  }

  static final _naturalToken = RegExp(r'(\d+|\D+)');

  static int _compareNatural(String left, String right) {
    final leftTokens = _naturalToken
        .allMatches(left.trim().toLowerCase())
        .map((m) => m.group(0)!)
        .toList(growable: false);
    final rightTokens = _naturalToken
        .allMatches(right.trim().toLowerCase())
        .map((m) => m.group(0)!)
        .toList(growable: false);
    final length = leftTokens.length < rightTokens.length
        ? leftTokens.length
        : rightTokens.length;
    for (var i = 0; i < length; i++) {
      final a = leftTokens[i];
      final b = rightTokens[i];
      final aNum = int.tryParse(a);
      final bNum = int.tryParse(b);
      final cmp = (aNum != null && bNum != null)
          ? aNum.compareTo(bNum)
          : a.compareTo(b);
      if (cmp != 0) return cmp;
    }
    return leftTokens.length.compareTo(rightTokens.length);
  }

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
    DateTime? thumbnailCapturedAt,
    bool clearThumbnailCapturedAt = false,
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
      thumbnailCapturedAt: clearThumbnailCapturedAt
          ? null
          : thumbnailCapturedAt ?? this.thumbnailCapturedAt,
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
    'thumbnailCapturedAt': thumbnailCapturedAt?.toUtc().toIso8601String(),
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
      thumbnailCapturedAt: json['thumbnailCapturedAt'] == null
          ? null
          : DateTime.parse(json['thumbnailCapturedAt'] as String).toUtc(),
    );
  }
}
