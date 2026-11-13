import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../features/camera_catalog/presentation/camera_catalog_page.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/layouts/presentation/layouts_page.dart';
import '../features/monitor/presentation/monitor_page.dart';
import '../features/settings/presentation/settings_page.dart';
import '../features/settings/presentation/global_connection_page.dart';
import '../shared/design_system/app_logo.dart';
import '../shared/platform/android_file_import_service.dart';
import '../shared/platform/device_environment.dart';
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
  AppSection _section = AppSection.monitor;
  bool _startupApplied = false;
  bool _tutorialQueued = false;
  bool? _lastFullscreen;
  final _fileImportService = AndroidFileImportService();
  StreamSubscription<IncomingBackupFile>? _fileSubscription;

  @override
  void initState() {
    super.initState();
    _fileSubscription = _fileImportService.fileStream.listen((file) {
      if (mounted) _handleIncomingBackupFile(file);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final initial = await _fileImportService.getInitialFile();
      if (initial != null && mounted) {
        _handleIncomingBackupFile(initial);
      }
    });
  }

  @override
  void dispose() {
    _fileSubscription?.cancel();
    _fileImportService.dispose();
    super.dispose();
  }

  Future<void> _handleIncomingBackupFile(IncomingBackupFile file) async {
    final store = AppScope.of(context);
    try {
      final decoded = jsonDecode(file.content);
      if (decoded is! Map) throw const FormatException();
      final isHubBackup = decoded['format'] == 'rtsp_hub_backup';
      final rawConfig = isHubBackup ? decoded['configuration'] : decoded;
      final rawCameras = rawConfig is Map ? rawConfig['cameras'] : null;
      final cameraCount = rawCameras is List ? rawCameras.length : 0;

      final confirm = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.settings_backup_restore_outlined, size: 36),
          title: const Text('Restaurar backup recebido?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                file.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Este arquivo contém $cameraCount câmera(s) e preferências. Pode incluir dados de acesso.',
              ),
              const SizedBox(height: 12),
              const Text(
                'Deseja importar e substituir as configurações atuais pelas deste arquivo?',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.download_done),
              label: const Text('Importar e abrir monitor'),
            ),
          ],
        ),
      );

      if (confirm == true && mounted) {
        final success = await store.importConfiguration(file.content);
        if (!mounted) return;
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Backup importado com sucesso! Câmeras e configurações atualizadas.',
              ),
            ),
          );
          _selectSection(AppSection.monitor);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                store.message ?? 'Falha ao importar o arquivo de backup.',
              ),
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'O arquivo recebido não é um backup válido do RTSP Hub.',
            ),
          ),
        );
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = AppScope.of(context);
    if (!_startupApplied && !store.loading) {
      _startupApplied = true;
      _section = widget.forceConfiguration
          ? AppSection.cameras
          : store.config.simpleMode
          ? AppSection.monitor
          : store.config.simpleMode
          ? AppSection.monitor
          : switch (store.config.startupSection) {
              'monitor' => AppSection.monitor,
              'cameras' => AppSection.cameras,
              'layouts' => AppSection.layouts,
              'settings' => AppSection.settings,
              'last' => _sectionFromName(store.config.lastSection),
              'auto' => AppSection.monitor,
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
        icon: const Center(child: AppLogo(size: 64)),
        title: const Text('Bem-vindo ao RTSP Hub'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '1. Encontre câmeras na rede ou cadastre o IP. Use Testar vídeo para conferir a imagem.',
            ),
            const SizedBox(height: 12),
            const Text(
              '2. Escolha um layout; câmeras novas ocupam espaços vazios.',
            ),
            const SizedBox(height: 12),
            Text(
              DeviceEnvironmentScope.of(context).isTelevision
                  ? '3. Abra o monitor. Use as setas para selecionar, OK para ampliar e Voltar para retornar à grade. Ajustes permite escolher quantas câmeras aparecem por página.'
                  : '3. Toque nas câmeras para ver os controles. Amplie uma imagem ou troque a câmera de cada espaço.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Pular'),
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
    final television = DeviceEnvironmentScope.of(context).isTelevision;
    final simple = AppScope.of(context).config.simpleMode;
    final destinations = _destinations
        .where((item) => !simple || item.$1 != AppSection.dashboard)
        .toList();
    final navigationIndex = destinations.indexWhere(
      (item) => item.$1 == _section,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final shortLandscape = height < 460 && width >= 480;
        final compact = width < 640 && !shortLandscape;
        final rail = (width >= 640 && width < 1100) || shortLandscape;
        return PopScope<Object?>(
          canPop:
              _section == AppSection.dashboard ||
              _section == AppSection.monitor,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop && _section != AppSection.monitor) {
              _selectSection(AppSection.dashboard);
            }
          },
          child: Scaffold(
            body: SafeArea(
              top: television && _section != AppSection.monitor,
              bottom: television && _section != AppSection.monitor,
              left: television && _section != AppSection.monitor,
              right: television && _section != AppSection.monitor,
              minimum: television && _section != AppSection.monitor
                  ? const EdgeInsets.symmetric(horizontal: 24, vertical: 12)
                  : EdgeInsets.zero,
              child: Row(
                children: [
                  if (!compact && rail && _section != AppSection.monitor)
                    NavigationRail(
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerLow,
                      leading: shortLandscape
                          ? null
                          : Padding(
                              padding: const EdgeInsets.only(
                                bottom: 20,
                                top: 12,
                              ),
                              child: const AppLogo(),
                            ),
                      selectedIndex: navigationIndex < 0 ? 0 : navigationIndex,
                      labelType: shortLandscape
                          ? NavigationRailLabelType.none
                          : NavigationRailLabelType.all,
                      onDestinationSelected: (index) =>
                          _selectSection(destinations[index].$1),
                      destinations: [
                        for (final item in destinations)
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
                      onSelected: _selectSection,
                    ),
                  Expanded(child: _pages[_selectedIndex]),
                ],
              ),
            ),
            bottomNavigationBar: compact && _section != AppSection.monitor
                ? NavigationBar(
                    selectedIndex: navigationIndex < 0 ? 0 : navigationIndex,
                    onDestinationSelected: (index) =>
                        _selectSection(destinations[index].$1),
                    destinations: [
                      for (final item in destinations)
                        NavigationDestination(
                          icon: Icon(item.$3),
                          selectedIcon: Icon(item.$4),
                          label: item.$2,
                        ),
                    ],
                  )
                : null,
          ),
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
        final applied = await store.applyMonitorProfile(profileId);
        if (!mounted) return;
        if (applied) {
          _selectIndex(3);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                store.message ?? 'Não foi possível abrir o perfil.',
              ),
            ),
          );
        }
      },
    ),
    const CameraCatalogPage(),
    LayoutsPage(onOpenMonitor: () => _selectIndex(3)),
    MonitorPage(
      onExit: () => _selectSection(
        AppScope.of(context).config.simpleMode
            ? AppSection.settings
            : AppSection.dashboard,
      ),
      onConfigure: () => _selectIndex(1),
      onOpenLayouts: () => _selectIndex(2),
    ),
    SettingsPage(onImported: () => _selectSection(AppSection.monitor)),
  ];

  void _selectIndex(int index) {
    _selectSection(_destinations[index].$1);
  }

  void _selectSection(AppSection section) {
    if (_section == section) return;
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
    (AppSection.dashboard, 'Início', Icons.home_outlined),
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
      width: 220,
      color: colors.surfaceContainerLow,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 30, 16, 30),
              child: Row(
                children: [
                  const AppLogo(size: 36),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: 'RTSP '),
                          TextSpan(
                            text: 'Hub',
                            style: TextStyle(color: colors.primary),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final item in _items.where(
                      (item) =>
                          !AppScope.of(context).config.simpleMode ||
                          item.$1 != AppSection.dashboard,
                    ))
                      _SidebarDestination(
                        section: item.$1,
                        label: item.$2,
                        icon: item.$3,
                        selected: item.$1 == section,
                        onTap: () => onSelected(item.$1),
                      ),
                  ],
                ),
              ),
            ),
            if (!AppScope.of(context).config.simpleMode)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Material(
                  color: Colors.transparent,
                  child: ListTile(
                    leading: Icon(
                      Icons.settings_ethernet,
                      color: colors.primary,
                    ),
                    minLeadingWidth: 24,
                    horizontalTitleGap: 10,
                    title: Text(
                      'Conexão global',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                    onTap: () => GlobalConnectionPage.open(context),
                  ),
                ),
              ),
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
                  const SizedBox(width: 18),
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
