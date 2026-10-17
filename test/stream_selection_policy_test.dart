import 'package:flutter_test/flutter_test.dart';
import 'package:rtsp_hub/features/monitor/domain/stream_selection_policy.dart';

void main() {
  test('manual economy mode can override the quality preset and focus', () {
    expect(
      StreamSelectionPolicy.useMainStream(
        resourceMode: 'quality',
        manualChoice: false,
        focused: true,
      ),
      isFalse,
    );
    expect(
      StreamSelectionPolicy.useMainStream(
        resourceMode: 'light',
        manualChoice: true,
      ),
      isTrue,
    );
  });

  test('automatic mode follows presets and favors the focused camera', () {
    expect(StreamSelectionPolicy.useMainStream(resourceMode: 'light'), isFalse);
    expect(
      StreamSelectionPolicy.useMainStream(resourceMode: 'balanced'),
      isFalse,
    );
    expect(
      StreamSelectionPolicy.useMainStream(resourceMode: 'quality'),
      isTrue,
    );
    expect(
      StreamSelectionPolicy.useMainStream(resourceMode: 'light', focused: true),
      isTrue,
    );
  });

  test('falls back to the only available stream', () {
    expect(
      StreamSelectionPolicy.useMainStream(
        resourceMode: 'light',
        manualChoice: false,
        hasSubStream: false,
      ),
      isTrue,
    );
  });
}
