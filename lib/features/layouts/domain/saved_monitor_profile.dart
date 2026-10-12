class SavedMonitorProfile {
  const SavedMonitorProfile({
    required this.id,
    required this.name,
    required this.layoutId,
    required this.slotCameraIds,
    this.startupSection = 'auto',
  });

  final String id;
  final String name;
  final String layoutId;
  final List<String?> slotCameraIds;
  final String startupSection;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'layoutId': layoutId,
    'slotCameraIds': slotCameraIds,
    'startupSection': startupSection,
  };

  factory SavedMonitorProfile.fromJson(Map<String, Object?> json) {
    final rawSlots = json['slotCameraIds'] as List? ?? const [];
    return SavedMonitorProfile(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      layoutId: json['layoutId'] as String? ?? 'GRID_4',
      slotCameraIds: rawSlots.map((value) => value as String?).toList(),
      startupSection: switch (json['startupSection']) {
        'auto' ||
        'dashboard' ||
        'monitor' ||
        'cameras' ||
        'layouts' ||
        'settings' ||
        'last' => json['startupSection'] as String,
        _ => 'auto',
      },
    );
  }
}
