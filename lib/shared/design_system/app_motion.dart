import 'package:material_ui/material_ui.dart';

class AppMotion {
  static const entranceDuration = Duration(milliseconds: 260);
  static const focusDuration = Duration(milliseconds: 220);
  static const launchDuration = Duration(milliseconds: 720);

  static bool reduced(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context) ||
      MediaQuery.accessibleNavigationOf(context);
}

class MotionEntrance extends StatefulWidget {
  const MotionEntrance({
    required this.child,
    this.replayKey,
    this.beginScale = 1,
    this.offset = const Offset(0, 0.018),
    super.key,
  });

  final Widget child;
  final Object? replayKey;
  final double beginScale;
  final Offset offset;

  @override
  State<MotionEntrance> createState() => _MotionEntranceState();
}

class _MotionEntranceState extends State<MotionEntrance>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: AppMotion.entranceDuration,
  );
  late final _progress = _controller.drive(
    CurveTween(curve: Curves.easeOutCubic),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _controller.value = 1;
      _started = true;
    } else if (!_started) {
      _started = true;
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(MotionEntrance oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.replayKey != widget.replayKey) {
      if (AppMotion.reduced(context)) {
        _controller.value = 1;
      } else {
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _progress,
    child: SlideTransition(
      position: _progress.drive(Tween(begin: widget.offset, end: Offset.zero)),
      child: widget.beginScale == 1
          ? widget.child
          : ScaleTransition(
              scale: _progress.drive(Tween(begin: widget.beginScale, end: 1.0)),
              child: widget.child,
            ),
    ),
  );
}
