class SavedMonitorProfile {
  const SavedMonitorProfile({
    required this.id,
    required this.name,
    required this.layoutId,
    required this.slotCameraIds,
  });

  final String id;
  final String name;
  final String layoutId;
  final List<String?> slotCameraIds;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'layoutId': layoutId,
    'slotCameraIds': slotCameraIds,
  };

  factory SavedMonitorProfile.fromJson(Map<String, Object?> json) {
    final rawSlots = json['slotCameraIds'] as List? ?? const [];
    return SavedMonitorProfile(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      layoutId: json['layoutId'] as String? ?? 'GRID_4',
      slotCameraIds: rawSlots.map((value) => value as String?).toList(),
    );
  }
}
