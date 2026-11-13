import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:rtsp_hub/app/data/transfer_codec.dart';
import 'package:rtsp_hub/features/settings/presentation/transfer_export_dialog.dart';

void main() {
  for (final size in [const Size(320, 568), const Size(1200, 900)]) {
    testWidgets('QR share fits $size and copies a portable code', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      const source = '{"format":"rtsp-hub-profiles","version":3,"profiles":[]}';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransferExportDialog(
              json: source,
              includesCredentials: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(QrImageView), findsOneWidget);
      await tester.ensureVisible(find.text('Copiar código'));
      await tester.tap(find.text('Copiar código'));
      await tester.pumpAndSettle();
      expect(jsonDecode(TransferCodec.decode(copied!)), jsonDecode(source));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('large profile offers file instead of an unreadable QR', (
    tester,
  ) async {
    final random = Random(9);
    final source = jsonEncode({
      'data': List.generate(
        8000,
        (_) => String.fromCharCode(33 + random.nextInt(80)),
      ).join(),
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TransferExportDialog(json: source, includesCredentials: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsNothing);
    expect(find.textContaining('grande demais'), findsOneWidget);
    expect(find.text('Arquivo compacto'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
