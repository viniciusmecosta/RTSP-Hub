import 'freeform_slot.dart';

class SavedMonitorProfile {
  const SavedMonitorProfile({
    required this.id,
    required this.name,
    required this.layoutId,
    required this.slotCameraIds,
    this.freeformSlots = const [],
    this.startupSection = 'auto',
  });

  final String id;
  final String name;
  final String layoutId;
  final List<String?> slotCameraIds;
  final List<FreeformSlot> freeformSlots;
  final String startupSection;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'layoutId': layoutId,
    'slotCameraIds': slotCameraIds,
    'freeformSlots': freeformSlots.map((s) => s.toJson()).toList(),
    'startupSection': startupSection,
  };

  factory SavedMonitorProfile.fromJson(Map<String, Object?> json) {
    final rawSlots = json['slotCameraIds'] as List? ?? const [];
    final rawFreeform = json['freeformSlots'] as List? ?? const [];
    return SavedMonitorProfile(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      layoutId: json['layoutId'] as String? ?? 'GRID_4',
      slotCameraIds: rawSlots.map((value) => value as String?).toList(),
      freeformSlots: rawFreeform
          .map(
            (item) =>
                FreeformSlot.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
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
