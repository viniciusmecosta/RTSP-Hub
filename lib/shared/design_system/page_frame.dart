import 'package:flutter/material.dart';

class PageFrame extends StatelessWidget {
  const PageFrame({
    required this.title,
    required this.subtitle,
    required this.child,
    this.actions = const [],
    this.maxContentWidth = 1400,
    super.key,
  }) : slivers = null;

  const PageFrame.slivers({
    required this.title,
    required this.subtitle,
    required this.slivers,
    this.actions = const [],
    this.maxContentWidth = 1400,
    super.key,
  }) : child = null;

  final String title;
  final String subtitle;
  final Widget? child;
  final List<Widget>? slivers;
  final List<Widget> actions;
  final double maxContentWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => _build(context, constraints.maxWidth),
  );

  Widget _build(BuildContext context, double width) {
    final padding = width < 380
        ? 12.0
        : width < 600
        ? 16.0
        : 32.0;
    final contentSlivers = slivers;
    if (contentSlivers != null) {
      final side = (width - maxContentWidth) / 2 > padding
          ? (width - maxContentWidth) / 2
          : padding;
      return SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(side, 24, side, 28),
              sliver: SliverToBoxAdapter(child: _heading(context, width)),
            ),
            for (final sliver in contentSlivers)
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: side),
                sliver: sliver,
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
          ],
        ),
      );
    }
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(padding, 24, padding, 28),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxContentWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _heading(context, width),
                      const SizedBox(height: 28),
                      child!,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heading(BuildContext context, double width) {
    if (width < 800 || MediaQuery.textScalerOf(context).scale(14) > 20) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PageHeading(title: title, subtitle: subtitle),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(spacing: 10, runSpacing: 8, children: actions),
          ],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _PageHeading(title: title, subtitle: subtitle),
        ),
        if (actions.isNotEmpty) const SizedBox(width: 24),
        Wrap(spacing: 8, runSpacing: 8, children: actions),
      ],
    );
  }
}

class _PageHeading extends StatelessWidget {
  const _PageHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: width < 400
              ? Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)
              : Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class EmptyPanel extends StatelessWidget {
  const EmptyPanel({
    required this.icon,
    required this.title,
    required this.description,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 64,
              width: 64,
              decoration: BoxDecoration(
                color: color.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(icon, size: 30, color: color.primary),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Text(
                description,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: color.onSurfaceVariant),
              ),
            ),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}
