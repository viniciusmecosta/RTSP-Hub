import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_selector/file_selector.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../app/state/app_store.dart';
import '../../../shared/design_system/page_frame.dart';
import '../../../shared/platform/windows_startup_service.dart';
import '../../../shared/platform/linux_startup_service.dart';
import 'global_connection_page.dart';
import '../domain/performance_preset.dart';
import '../../monitor/domain/rtsp_buffer_policy.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _windowsStartup = WindowsStartupService();
  final _linuxStartup = LinuxStartupService();
  bool _startupEnabled = false;
  bool _startupLoading = false;
  bool _backupBusy = false;
  final Future<PackageInfo?> _packageInfo = _readPackageInfo();

  static Future<PackageInfo?> _readPackageInfo() async {
    try {
      return await PackageInfo.fromPlatform();
    } on Object {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadStartupState());
  }

  Future<void> _loadStartupState() async {
    final enabled = Platform.isWindows
        ? await _windowsStartup.isEnabled()
        : Platform.isLinux
        ? await _linuxStartup.isEnabled()
        : false;
    if (!mounted) return;
    setState(() {
      _startupEnabled = enabled;
      _startupLoading = false;
    });
  }

  Future<void> _setStartupState(bool enabled) async {
    setState(() => _startupLoading = true);
    final saved = Platform.isWindows
        ? await _windowsStartup.setEnabled(enabled)
        : Platform.isLinux
        ? await _linuxStartup.setEnabled(enabled)
        : false;
    if (!mounted) return;
    setState(() {
      _startupEnabled = saved ? enabled : _startupEnabled;
      _startupLoading = false;
    });
    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível alterar a inicialização do sistema.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    return PageFrame(
      title: 'Ajustes',
      subtitle: 'Personalize a experiência, o desempenho e seus dados.',
      maxContentWidth: 1040,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const GlobalConnectionShortcut(),
          const SizedBox(height: 24),
          Text(
            'Aparência e inicialização',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                _SettingDropdownTile<ThemeMode>(
                  icon: Icons.palette_outlined,
                  title: 'Aparência',
                  subtitle: 'Tema claro, escuro ou automático',
                  value: store.themeMode,
                  items: const [
                    DropdownMenuItem(
                      value: ThemeMode.system,
                      child: Text('Sistema'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.light,
                      child: Text('Claro'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.dark,
                      child: Text('Escuro'),
                    ),
                  ],
                  onChanged: (mode) {
                    if (mode != null) store.setThemeMode(mode);
                  },
                ),
                const Divider(height: 1),
                _SettingDropdownTile<String>(
                  icon: Icons.start_outlined,
                  title: 'Ao abrir o aplicativo',
                  subtitle:
                      'Automático escolhe o monitor quando há câmeras na grade; Última tela usada retoma onde você saiu.',
                  value: store.config.startupSection,
                  items: const [
                    DropdownMenuItem(value: 'auto', child: Text('Automático')),
                    DropdownMenuItem(
                      value: 'last',
                      child: Text('Última tela usada'),
                    ),
                    DropdownMenuItem(value: 'dashboard', child: Text('Início')),
                    DropdownMenuItem(value: 'monitor', child: Text('Monitor')),
                    DropdownMenuItem(value: 'cameras', child: Text('Câmeras')),
                    DropdownMenuItem(value: 'layouts', child: Text('Layouts')),
                    DropdownMenuItem(value: 'settings', child: Text('Ajustes')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      store.updateSettings(startupSection: value);
                    }
                  },
                ),
                if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) ...[
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: _startupLoading
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.power_settings_new_outlined),
                    title: Text(
                      Platform.isWindows
                          ? 'Iniciar com o Windows'
                          : 'Iniciar com o Linux',
                    ),
                    subtitle: const Text(
                      'Abre automaticamente na tela escolhida acima.',
                    ),
                    value: _startupEnabled,
                    onChanged: _startupLoading ? null : _setStartupState,
                  ),
                ],
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.fullscreen_outlined),
                  title: const Text('Abrir monitor em tela cheia'),
                  subtitle: const Text(
                    'Aplicado ao entrar no monitor em desktop.',
                  ),
                  value: store.config.autoFullscreen,
                  onChanged: (value) =>
                      store.updateSettings(autoFullscreen: value),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Reprodução e desempenho',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                _SettingDropdownTile<String>(
                  icon: Icons.memory_outlined,
                  title: 'Perfil de desempenho',
                  subtitle:
                      'O fluxo secundário reduz o trabalho do computador. O cache varia conforme a taxa do vídeo.',
                  value: store.config.resourceMode,
                  items: [
                    for (final preset in PerformancePreset.values)
                      DropdownMenuItem(
                        value: preset.id,
                        child: Text(preset.label),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      store.updateSettings(
                        resourceMode: value,
                        bufferMs: PerformancePreset.fromId(value).bufferMs,
                      );
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.high_quality_outlined),
                  title: const Text('Cache de rede por câmera'),
                  subtitle: Text(
                    'Econômico: ${RtspBufferPolicy.bytesFor(targetMilliseconds: store.config.bufferMs, mainStream: false) ~/ 1024} KiB · principal: ${RtspBufferPolicy.bytesFor(targetMilliseconds: store.config.bufferMs, mainStream: true) ~/ 1024} KiB. Limite de cache, sem reduzir a resolução. Decodificação e imagens usam memória adicional.',
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                  child: Text(
                    PerformancePreset.fromId(
                      store.config.resourceMode,
                    ).description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Backup e restauração',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Transfira câmeras, perfis, preferências, miniaturas e todas as credenciais. O arquivo inclui senhas legíveis; guarde-o em um local privado.',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _backupBusy
                            ? null
                            : () => _runBackup(
                                () => _exportBackup(context, store),
                              ),
                        icon: const Icon(Icons.save_alt_outlined),
                        label: Text(
                          _backupBusy
                              ? 'Processando…'
                              : 'Exportar backup completo',
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _backupBusy
                            ? null
                            : () => _runBackup(
                                () => _importBackup(context, store),
                              ),
                        icon: const Icon(Icons.restore_outlined),
                        label: const Text('Importar backup'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FutureBuilder<PackageInfo?>(
            future: _packageInfo,
            builder: (context, snapshot) {
              final info = snapshot.data;
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('RTSP Hub'),
                  subtitle: Text(
                    info == null
                        ? 'Informações de versão indisponíveis'
                        : 'Versão ${info.version}${info.buildNumber.isEmpty ? '' : ' · compilação ${info.buildNumber}'}',
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _importBackup(BuildContext context, AppStore store) async {
    String source;
    try {
      final backup = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(label: 'Backup RTSP Hub', extensions: ['json']),
        ],
      );
      if (backup == null) return;
      if (await backup.length() > AppStore.maxBackupBytes) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('O backup excede o limite de 64 MB.')),
          );
        }
        return;
      }
      source = await backup.readAsString();
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível abrir o arquivo de backup.'),
          ),
        );
      }
      return;
    }
    if (!context.mounted) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Substituir configurações?'),
        content: const Text(
          'O backup completo substituirá câmeras, layouts, preferências, miniaturas e credenciais deste dispositivo. Arquivos antigos de configuração continuam aceitos, mas não contêm senhas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Importar'),
          ),
        ],
      ),
    );
    if (accepted != true) return;
    final imported = await store.importConfiguration(source);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          imported
              ? 'Restauração concluída. Backups antigos sem credenciais mantêm as senhas locais existentes.'
              : store.message ?? 'O backup não pôde ser importado.',
        ),
      ),
    );
  }

  Future<void> _runBackup(Future<void> Function() operation) async {
    if (_backupBusy) return;
    setState(() => _backupBusy = true);
    try {
      await operation();
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível concluir o backup. Confira o acesso aos arquivos e ao cofre.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

  Future<void> _exportBackup(BuildContext context, AppStore store) async {
    final content = await store.exportBackup();
    if (!context.mounted) return;
    final now = DateTime.now();
    final filename = 'rtsp-hub-backup-${now.millisecondsSinceEpoch}.json';
    if (Platform.isAndroid || Platform.isIOS) {
      final box = context.findRenderObject() as RenderBox?;
      final origin = box == null
          ? null
          : box.localToGlobal(Offset.zero) & box.size;
      final directory = Directory(
        '${(await getTemporaryDirectory()).path}/hub-backup',
      );
      await directory.create(recursive: true);
      await for (final entry in directory.list()) {
        if (entry is File &&
            DateTime.now().difference((await entry.stat()).modified).inDays >=
                1) {
          await entry.delete();
        }
      }
      final file = File('${directory.path}/$filename');
      await file.writeAsString(content, flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/json')],
          sharePositionOrigin: origin,
          title: 'Salvar backup completo',
        ),
      );
      return;
    }
    final location = await getSaveLocation(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Backup RTSP Hub', extensions: ['json']),
      ],
      suggestedName: filename,
    );
    if (location == null) return;
    await File(location.path).writeAsString(content, flush: true);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Backup completo salvo com credenciais e miniaturas.'),
        ),
      );
    }
  }
}

class _SettingDropdownTile<T> extends StatelessWidget {
  const _SettingDropdownTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 560) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      icon,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 40),
                  child: DropdownButton<T>(
                    value: value,
                    items: items,
                    onChanged: onChanged,
                    isExpanded: true,
                  ),
                ),
              ],
            ),
          );
        }
        return ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: DropdownButton<T>(
            value: value,
            items: items,
            onChanged: onChanged,
          ),
        );
      },
    );
  }
}
