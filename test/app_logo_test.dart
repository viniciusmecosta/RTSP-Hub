import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rtsp_hub/shared/design_system/app_logo.dart';
import 'package:rtsp_hub/shared/design_system/app_theme.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final ratio in [1.0, 2.0, 3.0]) {
      testWidgets('marca legivel em $brightness com densidade $ratio', (
        tester,
      ) async {
        tester.view.devicePixelRatio = ratio;
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: brightness == Brightness.dark
                ? AppTheme.dark
                : AppTheme.light,
            home: const Center(child: AppLogo(size: 32)),
          ),
        );
        await tester.pumpAndSettle();
        final image = tester.widget<Image>(find.byType(Image));
        final provider = image.image as ResizeImage;
        expect(provider.width, (32 * ratio).ceil());
        expect(provider.height, (32 * ratio).ceil());
        expect(tester.getSize(find.byType(Image)), const Size(32, 32));
        expect(image.excludeFromSemantics, isTrue);
        expect(image.gaplessPlayback, isTrue);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('limita a decodificacao a resolucao do arquivo', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Center(child: AppLogo(size: 2048))),
    );
    await tester.pumpAndSettle();
    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image as ResizeImage;
    expect(provider.width, AppLogo.sourceSize);
    expect(provider.height, AppLogo.sourceSize);
    expect(tester.takeException(), isNull);
  });

  testWidgets('marca isolada oferece nome acessivel quando solicitado', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        const MaterialApp(home: AppLogo(semanticLabel: 'RTSP Hub')),
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('RTSP Hub'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });
}
