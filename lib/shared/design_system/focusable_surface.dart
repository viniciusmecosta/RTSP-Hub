import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FocusableSurface extends StatefulWidget {
  const FocusableSurface({
    required this.child,
    required this.onActivate,
    this.onFocusChanged,
    this.autofocus = false,
    this.label,
    super.key,
  });

  final Widget child;
  final VoidCallback? onActivate;
  final ValueChanged<bool>? onFocusChanged;
  final bool autofocus;
  final String? label;

  @override
  State<FocusableSurface> createState() => _FocusableSurfaceState();
}

class _FocusableSurfaceState extends State<FocusableSurface> {
  bool _highlight = false;

  @override
  Widget build(BuildContext context) => FocusableActionDetector(
    enabled: widget.onActivate != null,
    autofocus: widget.autofocus,
    onFocusChange: widget.onFocusChanged,
    onShowFocusHighlight: (value) {
      if (_highlight != value) setState(() => _highlight = value);
    },
    shortcuts: const {
      SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
      SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
      SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
      SingleActivator(LogicalKeyboardKey.gameButtonA): ActivateIntent(),
    },
    actions: {
      ActivateIntent: CallbackAction<ActivateIntent>(
        onInvoke: (_) {
          widget.onActivate?.call();
          return null;
        },
      ),
    },
    child: Semantics(
      label: widget.label,
      button: widget.onActivate != null,
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          if (_highlight)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  key: const ValueKey('keyboard-focus-outline'),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFF9FC2FF),
                      width: 3,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
