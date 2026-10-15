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
              'settings' => AppSection.settings,
              'last' => _sectionFromName(store.config.lastSection),
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
        title: const Text('Bem-vindo ao RTSP Hub'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '1. Encontre câmeras na rede ou cadastre o IP. Use Testar vídeo para conferir a imagem.',
            ),
            SizedBox(height: 12),
            Text('2. Escolha um layout; câmeras novas ocupam espaços vazios.'),
            SizedBox(height: 12),
            Text(
              '3. Abra o monitor para acompanhar as câmeras. No computador, use F3 para ver estados e Esc para voltar.',
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
        final height = constraints.maxHeight;
        final shortLandscape = height < 460 && width >= 480;
        final compact = width < 640 && !shortLandscape;
        final rail = (width >= 640 && width < 1100) || shortLandscape;
        return Scaffold(
          body: Row(
            children: [
              if (!compact && rail && _section != AppSection.monitor)
                NavigationRail(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerLow,
                  selectedIndex: _selectedIndex,
                  labelType: shortLandscape
                      ? NavigationRailLabelType.none
                      : NavigationRailLabelType.all,
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
      onOpenLayouts: () => _selectIndex(2),
      onOpenProfile: (profileId) async {
        final store = AppScope.of(context);
        await store.applyMonitorProfile(profileId);
        _selectIndex(3);
      },
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
    unawaited(AppScope.of(context).updateSettings(lastSection: section.name));
    _syncDesktopWindow(AppScope.of(context));
  }

  AppSection _sectionFromName(String name) => switch (name) {
    'monitor' => AppSection.monitor,
    'cameras' => AppSection.cameras,
    'layouts' => AppSection.layouts,
    'settings' => AppSection.settings,
    _ => AppSection.dashboard,
  };

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
    final colors = theme.colorScheme;
    return Container(
      key: const ValueKey('desktopSidebar'),
      width: 248,
      color: colors.surfaceContainerLow,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 26, 16, 30),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'assets/logo.png',
                      width: 42,
                      height: 42,
                      cacheWidth: 84,
                      semanticLabel: 'RTSP Hub',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'RTSP Hub',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'CENTRAL DE CÂMERAS',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.onSurfaceVariant,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            for (final item in _items)
              _SidebarDestination(
                section: item.$1,
                label: item.$2,
                icon: item.$3,
                selected: item.$1 == section,
                onTap: () => onSelected(item.$1),
              ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Row(
                children: [
                  Icon(
                    Icons.shield_outlined,
                    size: 17,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Monitoramento local',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarDestination extends StatelessWidget {
  const _SidebarDestination({
    required this.section,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final AppSection section;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = selected
        ? colors.onPrimaryContainer
        : colors.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Semantics(
        button: true,
        selected: selected,
        child: Material(
          key: ValueKey('sidebar_${section.name}'),
          color: selected ? colors.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              height: 52,
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 24,
                    decoration: BoxDecoration(
                      color: selected ? colors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 17),
                  Icon(icon, size: 22, color: foreground),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: foreground,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
