import '../../features/camera_catalog/domain/camera_device.dart';
import '../../features/layouts/domain/saved_monitor_profile.dart';

class AppConfiguration {
  const AppConfiguration({
    this.schemaVersion = 1,
    this.cameras = const [],
    this.monitorProfiles = const [],
    this.layoutId = 'GRID_4',
    this.slotCameraIds = const [null, null, null, null],
    this.defaultPort = 554,
    this.defaultUser = 'admin',
    this.defaultPath = '/Streaming/Channels/101',
    this.bufferMs = 300,
    this.resourceMode = 'eco',
    this.themeMode = 'system',
    this.autoFullscreen = true,
    this.startupSection = 'auto',
    this.tutorialCompleted = false,
  });

  final int schemaVersion;
  final List<CameraDevice> cameras;
  final List<SavedMonitorProfile> monitorProfiles;
  final String layoutId;
  final List<String?> slotCameraIds;
  final int defaultPort;
  final String defaultUser;
  final String defaultPath;
  final int bufferMs;
  final String resourceMode;
  final String themeMode;
  final bool autoFullscreen;
  final String startupSection;
  final bool tutorialCompleted;

  AppConfiguration copyWith({
    List<CameraDevice>? cameras,
    List<SavedMonitorProfile>? monitorProfiles,
    String? layoutId,
    List<String?>? slotCameraIds,
    int? defaultPort,
    String? defaultUser,
    String? defaultPath,
    int? bufferMs,
    String? resourceMode,
    String? themeMode,
    bool? autoFullscreen,
    String? startupSection,
    bool? tutorialCompleted,
  }) => AppConfiguration(
    schemaVersion: schemaVersion,
    cameras: cameras ?? this.cameras,
    monitorProfiles: monitorProfiles ?? this.monitorProfiles,
    layoutId: layoutId ?? this.layoutId,
    slotCameraIds: slotCameraIds ?? this.slotCameraIds,
    defaultPort: defaultPort ?? this.defaultPort,
    defaultUser: defaultUser ?? this.defaultUser,
    defaultPath: defaultPath ?? this.defaultPath,
    bufferMs: bufferMs ?? this.bufferMs,
    resourceMode: resourceMode ?? this.resourceMode,
    themeMode: themeMode ?? this.themeMode,
    autoFullscreen: autoFullscreen ?? this.autoFullscreen,
    startupSection: startupSection ?? this.startupSection,
    tutorialCompleted: tutorialCompleted ?? this.tutorialCompleted,
  );

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'savedAt': DateTime.now().toUtc().toIso8601String(),
    'settings': {
      'defaultPort': defaultPort,
      'defaultUser': defaultUser,
      'defaultPath': defaultPath,
      'bufferMs': bufferMs,
      'resourceMode': resourceMode,
      'themeMode': themeMode,
      'autoFullscreen': autoFullscreen,
      'startupSection': startupSection,
      'tutorialCompleted': tutorialCompleted,
    },
    'cameras': cameras.map((camera) => camera.toJson()).toList(),
    'monitorProfiles': monitorProfiles
        .map((profile) => profile.toJson())
        .toList(),
    'layout': {'id': layoutId, 'slots': slotCameraIds},
  };

  factory AppConfiguration.fromJson(Map<String, Object?> json) {
    final settings = Map<String, Object?>.from(
      json['settings'] as Map? ?? const {},
    );
    final layout = Map<String, Object?>.from(
      json['layout'] as Map? ?? const {},
    );
    final cameras = (json['cameras'] as List? ?? const [])
        .map(
          (item) =>
              CameraDevice.fromJson(Map<String, Object?>.from(item as Map)),
        )
        .toList(growable: false);
    final monitorProfiles = (json['monitorProfiles'] as List? ?? const [])
        .map(
          (item) => SavedMonitorProfile.fromJson(
            Map<String, Object?>.from(item as Map),
          ),
        )
        .toList(growable: false);
    final slots = (layout['slots'] as List? ?? const [])
        .map((item) => item as String?)
        .toList(growable: false);
    return AppConfiguration(
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
      cameras: cameras,
      monitorProfiles: monitorProfiles,
      layoutId: layout['id'] as String? ?? 'GRID_4',
      slotCameraIds: slots.isEmpty ? const [null, null, null, null] : slots,
      defaultPort: (settings['defaultPort'] as num?)?.toInt() ?? 554,
      defaultUser: settings['defaultUser'] as String? ?? 'admin',
      defaultPath:
          settings['defaultPath'] as String? ?? '/Streaming/Channels/101',
      bufferMs: (settings['bufferMs'] as num?)?.toInt() ?? 300,
      resourceMode: settings['resourceMode'] as String? ?? 'eco',
      themeMode: settings['themeMode'] as String? ?? 'system',
      autoFullscreen: settings['autoFullscreen'] as bool? ?? true,
      startupSection: switch (settings['startupSection']) {
        'auto' => 'auto',
        'dashboard' => 'dashboard',
        'monitor' ||
        'cameras' ||
        'layouts' => settings['startupSection'] as String,
        _ => 'auto',
      },
      tutorialCompleted: settings['tutorialCompleted'] as bool? ?? false,
    );
  }
}
