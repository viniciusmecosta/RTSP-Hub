import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rtsp_hub/features/monitor/application/rtsp_decode_budget.dart';

void main() {
  test('reduces only hidden decoding and restores the normal budget', () async {
    final changes = <String>[];
    final budget = RtspDecodeBudget(
      applySkipFrame: (value) async => changes.add(value),
    );
    await budget.setBackground(false);
    await budget.setBackground(true);
    await budget.setBackground(true);
    await budget.setBackground(false);
    expect(changes, ['default', 'nonref', 'default']);
    budget.dispose();
    await budget.setBackground(true);
    expect(changes.length, 3);
  });

  test('rapid transitions finish with the latest requested budget', () async {
    final gate = Completer<void>();
    final changes = <String>[];
    final budget = RtspDecodeBudget(
      applySkipFrame: (value) async {
        changes.add(value);
        await gate.future;
      },
    );
    final background = budget.setBackground(true);
    await Future<void>.value();
    final foreground = budget.setBackground(false);
    gate.complete();
    await Future.wait([background, foreground]);
    expect(changes, ['nonref', 'default']);
    budget.dispose();
  });

  test(
    'unsupported properties do not interrupt playback or other budgets',
    () async {
      final unavailable = RtspDecodeBudget(
        applySkipFrame: (_) async => throw StateError('Unsupported'),
      );
      final changes = <String>[];
      final healthy = RtspDecodeBudget(
        applySkipFrame: (value) async => changes.add(value),
      );
      await Future.wait([
        unavailable.setBackground(true),
        healthy.setBackground(true),
      ]);
      await unavailable.setBackground(false);
      await healthy.setBackground(false);
      expect(changes, ['nonref', 'default']);
      unavailable.dispose();
      healthy.dispose();
    },
  );

  test(
    'disposing during a transition prevents later property changes',
    () async {
      final gate = Completer<void>();
      final changes = <String>[];
      final budget = RtspDecodeBudget(
        applySkipFrame: (value) async {
          changes.add(value);
          await gate.future;
        },
      );
      final pending = budget.setBackground(true);
      await Future<void>.value();
      budget.setBackground(false);
      budget.dispose();
      gate.complete();
      await pending;
      expect(changes, ['nonref']);
    },
  );
}
