import 'dart:ui';

class FreeformSlot {
  const FreeformSlot({
    this.cameraId,
    this.x = 0.0,
    this.y = 0.0,
    this.width = 0.5,
    this.height = 0.5,
  });

  final String? cameraId;
  final double x;
  final double y;
  final double width;
  final double height;

  FreeformSlot copyWith({
    String? cameraId,
    bool clearCamera = false,
    double? x,
    double? y,
    double? width,
    double? height,
  }) {
    return FreeformSlot(
      cameraId: clearCamera ? null : (cameraId ?? this.cameraId),
      x: (x ?? this.x).clamp(0.0, 1.0),
      y: (y ?? this.y).clamp(0.0, 1.0),
      width: (width ?? this.width).clamp(0.05, 1.0),
      height: (height ?? this.height).clamp(0.05, 1.0),
    );
  }

  Rect toRect(Size canvas) {
    final left = x.clamp(0.0, 1.0) * canvas.width;
    final top = y.clamp(0.0, 1.0) * canvas.height;
    final w = (width.clamp(0.05, 1.0) * canvas.width).clamp(10.0, canvas.width);
    final h = (height.clamp(0.05, 1.0) * canvas.height).clamp(
      10.0,
      canvas.height,
    );
    return Rect.fromLTWH(left, top, w, h);
  }

  Map<String, dynamic> toJson() => {
    if (cameraId != null) 'cameraId': cameraId,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
  };

  factory FreeformSlot.fromJson(Map<String, dynamic> json) {
    return FreeformSlot(
      cameraId: json['cameraId'] as String?,
      x: (json['x'] as num?)?.toDouble().clamp(0.0, 1.0) ?? 0.0,
      y: (json['y'] as num?)?.toDouble().clamp(0.0, 1.0) ?? 0.0,
      width: (json['width'] as num?)?.toDouble().clamp(0.05, 1.0) ?? 0.5,
      height: (json['height'] as num?)?.toDouble().clamp(0.05, 1.0) ?? 0.5,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FreeformSlot &&
          runtimeType == other.runtimeType &&
          cameraId == other.cameraId &&
          (x - other.x).abs() < 0.0001 &&
          (y - other.y).abs() < 0.0001 &&
          (width - other.width).abs() < 0.0001 &&
          (height - other.height).abs() < 0.0001;

  @override
  int get hashCode => Object.hash(
    cameraId,
    (x * 1000).round(),
    (y * 1000).round(),
    (width * 1000).round(),
    (height * 1000).round(),
  );
}
