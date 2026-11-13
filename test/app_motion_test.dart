import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rtsp_hub/app/app_launch.dart';
import 'package:rtsp_hub/shared/design_system/app_logo.dart';
import 'package:rtsp_hub/shared/design_system/app_motion.dart';

void main() {
  testWidgets('entrance progresses and replay preserves the child state', (
    tester,
  ) async {
    late StateSetter update;
    var revision = 0;
    var mounts = 0;
    final child = _TrackedChild(onMount: () => mounts++);
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return MotionEntrance(replayKey: revision, child: child);
          },
        ),
      ),
    );
    final motion = find
        .descendant(
          of: find.byType(MotionEntrance),
          matching: find.byType(FadeTransition),
        )
        .first;
    double opacity() => tester.widget<FadeTransition>(motion).opacity.value;
    expect(opacity(), 0);
    await tester.pump(const Duration(milliseconds: 100));
    expect(opacity(), greaterThan(0));
    expect(opacity(), lessThan(1));
    await tester.pumpAndSettle();
    expect(opacity(), 1);
    final element = tester.element(find.byType(_TrackedChild));
    update(() => revision++);
    await tester.pump();
    expect(opacity(), 0);
    expect(tester.element(find.byType(_TrackedChild)), same(element));
    expect(mounts, 1);
    await tester.pumpAndSettle();
    expect(opacity(), 1);
  });

  testWidgets('changing pages disposes the old child before the new entrance', (
    tester,
  ) async {
    var disposed = 0;
    late StateSetter update;
    var monitor = false;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return MotionEntrance(
              replayKey: monitor,
              child: _TrackedChild(
                key: ValueKey(monitor),
                onMount: () {},
                onDispose: () => disposed++,
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    update(() => monitor = true);
    await tester.pump();
    expect(disposed, 1);
    expect(find.byType(_TrackedChild), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('launch animates once while the application is already mounted', (
    tester,
  ) async {
    var mounts = 0;
    final child = _TrackedChild(onMount: () => mounts++);
    Widget app() => MaterialApp(home: AppLaunch(child: child));
    await tester.pumpWidget(app());
    expect(mounts, 1);
    expect(find.byKey(const ValueKey('appLaunchOverlay')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(AppLogo), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('appLaunchOverlay')), findsNothing);
    await tester.pumpWidget(app());
    expect(find.byType(AppLogo), findsNothing);
    expect(mounts, 1);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets(
    'tapping launch skips it without activating the screen behind it',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: AppLaunch(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => taps++,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );
      await tester.tapAt(const Offset(100, 100));
      await tester.pump();
      expect(find.byKey(const ValueKey('appLaunchOverlay')), findsNothing);
      expect(taps, 0);
      await tester.tapAt(const Offset(100, 100));
      expect(taps, 1);
    },
  );

  for (final accessible in [false, true]) {
    testWidgets(
      'reduced motion skips launch and entrance (accessible: $accessible)',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                disableAnimations: !accessible,
                accessibleNavigation: accessible,
              ),
              child: const AppLaunch(
                child: MotionEntrance(child: Text('Monitor pronto')),
              ),
            ),
          ),
        );
        expect(find.byType(AppLogo), findsNothing);
        expect(find.text('Monitor pronto'), findsOneWidget);
        final fade = tester.widget<FadeTransition>(
          find
              .descendant(
                of: find.byType(MotionEntrance),
                matching: find.byType(FadeTransition),
              )
              .first,
        );
        expect(fade.opacity.value, 1);
        expect(tester.hasRunningAnimations, isFalse);
      },
    );
  }
}

class _TrackedChild extends StatefulWidget {
  const _TrackedChild({required this.onMount, this.onDispose, super.key});
  final VoidCallback onMount;
  final VoidCallback? onDispose;
  @override
  State<_TrackedChild> createState() => _TrackedChildState();
}

class _TrackedChildState extends State<_TrackedChild> {
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  void dispose() {
    widget.onDispose?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
