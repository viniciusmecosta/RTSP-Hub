import 'package:flutter_test/flutter_test.dart';
import 'package:rtsp_view/features/settings/domain/performance_preset.dart';

void main() {
  test('legacy eco mode maps to light mode for existing installations', () {
    expect(PerformancePreset.fromId('eco'), PerformancePreset.light);
    expect(PerformancePreset.fromId('invalid'), PerformancePreset.light);
  });

  test('presets trade decoder count and buffer for image quality', () {
    expect(
      PerformancePreset.light.bufferMs,
      lessThan(PerformancePreset.quality.bufferMs),
    );
  });
}
