import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../features/camera_catalog/presentation/camera_catalog_page.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/layouts/presentation/layouts_page.dart';
import '../features/monitor/presentation/monitor_page.dart';
import '../features/settings/presentation/settings_page.dart';
import 'state/app_store.dart';

enum AppSection { dashboard, cameras, layouts, monitor, settings }

class AppShell extends StatefulWidget {
  const AppShell({
    this.forceConfiguration = false,
    this.desktopWindowManager = false,
    super.key,
  });

  final bool forceConfiguration;
  final bool desktopWindowManager;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppSection _section = AppSection.dashboard;
  bool _startupApplied = false;
  bool _tutorialQueued = false;
  bool? _lastFullscreen;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = AppScope.of(context);
    if (!_startupApplied && !store.loading) {
      _startupApplied = true;
      _section = widget.forceConfiguration
          ? AppSection.cameras
          : switch (store.config.startupSection) {
              'monitor' => AppSection.monitor,
              'cameras' => AppSection.cameras,
              'layouts' => AppSection.layouts,
              'auto' =>
                store.cameras.isEmpty
                    ? AppSection.cameras
                    : store.config.slotCameraIds.any((id) => id != null)
                    ? AppSection.monitor
                    : AppSection.layouts,
              _ => AppSection.dashboard,
            };
    }
    if (_startupApplied && !_tutorialQueued && !store.loading) {
      _tutorialQueued = true;
      if (!store.config.tutorialCompleted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showFirstRunTutorial();
        });
      }
    }
    if (_startupApplied) _syncDesktopWindow(store);
  }

  Future<void> _showFirstRunTutorial() async {
    final store = AppScope.of(context);
    final openCameras = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.tips_and_updates_outlined),
        title: const Text('Bem-vindo ao RTSP View'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('1. Cadastre a câmera e teste a conexão RTSP.'),
            SizedBox(height: 12),
            Text('2. Escolha um layout; câmeras novas ocupam espaços vazios.'),
            SizedBox(height: 12),
            Text(
              '3. Abra o monitor. Use botão direito para focar, F3 para ver estados e Esc para voltar.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Entendi'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.videocam_outlined),
            label: const Text('Cadastrar câmera'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    await store.updateSettings(tutorialCompleted: true);
    if (openCameras == true && mounted) _selectIndex(1);
  }

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
                _DesktopSidebar(section: _section, onSelected: _selectSection),
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
    MonitorPage(
      onExit: () => _selectIndex(0),
      onConfigure: () => _selectIndex(1),
    ),
    const SettingsPage(),
  ];

  void _selectIndex(int index) {
    _selectSection(_destinations[index].$1);
  }

  void _selectSection(AppSection section) {
    setState(() => _section = section);
    _syncDesktopWindow(AppScope.of(context));
  }

  void _syncDesktopWindow(AppStore store) {
    if (!widget.desktopWindowManager ||
        kIsWeb ||
        (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS)) {
      return;
    }
    final fullscreen =
        _section == AppSection.monitor && store.config.autoFullscreen;
    if (_lastFullscreen == fullscreen) return;
    _lastFullscreen = fullscreen;
    unawaited(_setDesktopFullscreen(fullscreen));
  }

  Future<void> _setDesktopFullscreen(bool fullscreen) async {
    try {
      await windowManager.setFullScreen(fullscreen);
      if (!fullscreen) {
        await windowManager.setSize(const Size(1280, 800));
        await windowManager.center();
      }
    } on Object {
      _lastFullscreen = null;
    }
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
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
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
