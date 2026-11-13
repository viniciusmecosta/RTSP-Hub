import 'package:material_ui/material_ui.dart';

import '../shared/design_system/app_logo.dart';
import '../shared/design_system/app_motion.dart';

class AppLaunch extends StatefulWidget {
  const AppLaunch({required this.child, super.key});

  final Widget child;

  @override
  State<AppLaunch> createState() => _AppLaunchState();
}

class _AppLaunchState extends State<AppLaunch>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: AppMotion.launchDuration,
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
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      widget.child,
      ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            if (_controller.isCompleted) return const SizedBox.shrink();
            final progress = _controller.value;
            final reveal = const Interval(
              0.45,
              1,
              curve: Curves.easeInOutCubic,
            ).transform(progress);
            final logo = const Interval(
              0,
              0.65,
              curve: Curves.easeOutCubic,
            ).transform(progress);
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _controller.value = 1,
              child: Opacity(
                opacity: 1 - reveal,
                child: ColoredBox(
                  key: const ValueKey('appLaunchOverlay'),
                  color: Theme.of(context).colorScheme.surface,
                  child: Center(
                    child: Opacity(
                      opacity: const Interval(0, 0.3).transform(progress),
                      child: Transform.scale(
                        scale: 0.82 + 0.18 * logo,
                        child: child,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppLogo(size: 88),
              const SizedBox(height: 16),
              Text(
                'RTSP Hub',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
