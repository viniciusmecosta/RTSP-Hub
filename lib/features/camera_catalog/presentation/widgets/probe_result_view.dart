import 'package:flutter/material.dart';

class ProbeResultView extends StatelessWidget {
  const ProbeResultView({
    required this.message,
    required this.succeeded,
    super.key,
  });

  final String message;
  final bool? succeeded;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final testing = succeeded == null;
    final background = testing
        ? colors.surfaceContainerHighest
        : succeeded!
        ? colors.primaryContainer
        : colors.errorContainer;
    final foreground = testing
        ? colors.onSurfaceVariant
        : succeeded!
        ? colors.onPrimaryContainer
        : colors.onErrorContainer;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              testing
                  ? Icons.pending_outlined
                  : succeeded!
                  ? Icons.check_circle_outline
                  : Icons.error_outline,
              size: 20,
              color: foreground,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
