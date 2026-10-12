import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rtsp_view/features/monitor/domain/rtsp_failure_message.dart';

void main() {
  test('turns credential failures into an actionable message', () {
    final message = RtspFailureMessage.describe(
      'Server returned 401 Unauthorized for rtsp://admin:secret@camera/live',
    );

    expect(message, contains('recusou o usuário ou a senha'));
    expect(message, isNot(contains('secret')));
    expect(message, isNot(contains('rtsp://')));
  });

  test('turns invalid addresses into a safe message', () {
    final message = RtspFailureMessage.describe(
      const FormatException('Invalid character', 'admin:secret'),
    );

    expect(message, contains('endereço RTSP contém um valor inválido'));
    expect(message, isNot(contains('secret')));
  });

  test('identifies timeouts without exposing internal errors', () {
    final message = RtspFailureMessage.describe(
      TimeoutException('rtsp://admin:secret@camera/live'),
    );

    expect(message, contains('não respondeu a tempo'));
    expect(message, isNot(contains('secret')));
  });
}
