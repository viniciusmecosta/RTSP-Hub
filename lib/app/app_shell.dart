import 'package:flutter/material.dart';

import '../features/camera_catalog/presentation/camera_catalog_page.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/layouts/presentation/layouts_page.dart';
import '../features/monitor/presentation/monitor_page.dart';
import '../features/settings/presentation/settings_page.dart';

enum AppSection { dashboard, cameras, layouts, monitor, settings }

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppSection _section = AppSection.dashboard;

  static const _destinations = <(AppSection, String, IconData, IconData)>[
    (AppSection.dashboard, 'Início', Icons.home_outlined, Icons.home),
    (AppSection.cameras, 'Câmeras', Icons.videocam_outlined, Icons.videocam),
    (AppSection.layouts, 'Layouts', Icons.grid_view_outlined, Icons.grid_view),
    (AppSection.monitor, 'Monitor', Icons.monitor_outlined, Icons.monitor),
    (AppSection.settings, 'Ajustes', Icons.tune_outlined, Icons.tune),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final compact = width < 640;
        final rail = width >= 640 && width < 1100;
        return Scaffold(
          body: Row(
            children: [
              if (!compact && rail && _section != AppSection.monitor)
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  labelType: NavigationRailLabelType.all,
                  onDestinationSelected: _selectIndex,
                  destinations: [
                    for (final item in _destinations)
                      NavigationRailDestination(
                        icon: Icon(item.$3),
                        selectedIcon: Icon(item.$4),
                        label: Text(item.$2),
                      ),
                  ],
                ),
              if (!compact && !rail && _section != AppSection.monitor)
                _DesktopSidebar(
                  section: _section,
                  onSelected: (section) => setState(() => _section = section),
                ),
              Expanded(child: _pages[_selectedIndex]),
            ],
          ),
          bottomNavigationBar: compact && _section != AppSection.monitor
              ? NavigationBar(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _selectIndex,
                  destinations: [
                    for (final item in _destinations)
                      NavigationDestination(
                        icon: Icon(item.$3),
                        selectedIcon: Icon(item.$4),
                        label: item.$2,
                      ),
                  ],
                )
              : null,
        );
      },
    );
  }

  int get _selectedIndex =>
      _destinations.indexWhere((item) => item.$1 == _section);

  List<Widget> get _pages => [
    DashboardPage(
      onAddCamera: () => _selectIndex(1),
      onOpenMonitor: () => _selectIndex(3),
    ),
    const CameraCatalogPage(),
    const LayoutsPage(),
    MonitorPage(onExit: () => _selectIndex(0)),
    const SettingsPage(),
  ];

  void _selectIndex(int index) {
    setState(() => _section = _destinations[index].$1);
  }
}

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({required this.section, required this.onSelected});

  final AppSection section;
  final ValueChanged<AppSection> onSelected;

  static const _items = <(AppSection, String, IconData)>[
    (AppSection.dashboard, 'Visão geral', Icons.space_dashboard_outlined),
    (AppSection.cameras, 'Câmeras', Icons.videocam_outlined),
    (AppSection.layouts, 'Layouts', Icons.grid_view_outlined),
    (AppSection.monitor, 'Monitor', Icons.monitor_outlined),
    (AppSection.settings, 'Ajustes', Icons.tune_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(right: BorderSide(color: theme.dividerColor)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 24, 18, 26),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.videocam, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'RTSP View',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            for (final item in _items)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 3,
                ),
                child: ListTile(
                  selected: item.$1 == section,
                  leading: Icon(item.$3),
                  title: Text(item.$2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  onTap: () => onSelected(item.$1),
                ),
              ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                'Monitoramento local',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
