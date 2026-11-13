import 'dart:async';
import 'dart:convert';
import '../../../app/data/transfer_codec.dart';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../../shared/design_system/app_logo.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../app/state/app_store.dart';
import '../../../shared/design_system/page_frame.dart';
import '../../../shared/platform/windows_startup_service.dart';
import '../../../shared/platform/linux_startup_service.dart';
import 'global_connection_page.dart';
import 'credential_export_dialog.dart';
import 'transfer_export_dialog.dart';
import 'transfer_import_dialog.dart';
import '../domain/performance_preset.dart';
import '../../monitor/domain/rtsp_buffer_policy.dart';
import '../../../shared/platform/device_environment.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({this.onImported, super.key});

  final VoidCallback? onImported;

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
    final television = DeviceEnvironmentScope.of(context).isTelevision;
    return PageFrame(
      title: 'Ajustes',
      subtitle: 'Personalize a experiência, o desempenho e seus dados.',
      maxContentWidth: 1040,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.tune),
              title: Text(
                store.config.simpleMode ? 'Modo Simples' : 'Modo Avançado',
              ),
              subtitle: const Text(
                'Ative para mostrar conexões e todos os ajustes técnicos.',
              ),
              value: !store.config.simpleMode,
              onChanged: (advanced) =>
                  store.updateSettings(simpleMode: !advanced),
            ),
          ),
          if (!store.config.simpleMode) const GlobalConnectionShortcut(),
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
                if (!store.config.simpleMode)
                  _SettingDropdownTile<String>(
                    icon: Icons.start_outlined,
                    title: 'Ao abrir o aplicativo',
                    subtitle:
                        'Automático escolhe o monitor quando há câmeras na grade; Última tela usada retoma onde você saiu.',
                    value: store.config.startupSection,
                    items: const [
                      DropdownMenuItem(
                        value: 'auto',
                        child: Text('Automático'),
                      ),
                      DropdownMenuItem(
                        value: 'last',
                        child: Text('Última tela usada'),
                      ),
                      DropdownMenuItem(
                        value: 'dashboard',
                        child: Text('Início'),
                      ),
                      DropdownMenuItem(
                        value: 'monitor',
                        child: Text('Monitor'),
                      ),
                      DropdownMenuItem(
                        value: 'cameras',
                        child: Text('Câmeras'),
                      ),
                      DropdownMenuItem(
                        value: 'layouts',
                        child: Text('Layouts'),
                      ),
                      DropdownMenuItem(
                        value: 'settings',
                        child: Text('Ajustes'),
                      ),
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
          if (!store.config.simpleMode) ...[
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
                  _SettingDropdownTile<int>(
                    icon: Icons.view_comfortable_outlined,
                    title: 'Câmeras por página',
                    subtitle: television
                        ? 'Automático exibe até 4 câmeras na TV. Apenas a página visível reproduz vídeo.'
                        : 'Automático mostra a grade inteira. Use páginas menores para reduzir o consumo; as outras câmeras ficam em espera.',
                    value: store.config.monitorPageSize,
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('Automático')),
                      DropdownMenuItem(
                        value: -1,
                        child: Text('Todas da grade'),
                      ),
                      DropdownMenuItem(value: 1, child: Text('1 câmera')),
                      DropdownMenuItem(value: 2, child: Text('2 câmeras')),
                      DropdownMenuItem(value: 4, child: Text('4 câmeras')),
                      DropdownMenuItem(value: 6, child: Text('6 câmeras')),
                      DropdownMenuItem(value: 9, child: Text('9 câmeras')),
                      DropdownMenuItem(value: 16, child: Text('16 câmeras')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        store.updateSettings(monitorPageSize: value);
                      }
                    },
                  ),
                  const Divider(height: 1),
                  _SettingDropdownTile<String>(
                    icon: Icons.aspect_ratio_outlined,
                    title: 'Ajuste de vídeo no monitor',
                    subtitle:
                        'Inteligente estende o vídeo de forma controlada para aproveitar o espaço sem distorcer demais. Proporção original evita qualquer estiramento.',
                    value: store.config.videoFitMode,
                    items: const [
                      DropdownMenuItem(
                        value: 'smart',
                        child: Text('Inteligente (sem exagero)'),
                      ),
                      DropdownMenuItem(
                        value: 'contain',
                        child: Text('Proporção original'),
                      ),
                      DropdownMenuItem(
                        value: 'fill',
                        child: Text('Esticar ao máximo'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        store.updateSettings(videoFitMode: value);
                      }
                    },
                  ),
                  const Divider(height: 1),
                  _SettingDropdownTile<String>(
                    icon: Icons.hd_outlined,
                    title: 'Fluxo padrão no monitor',
                    subtitle:
                        'Subfluxo (SD) é mais econômico e leve para múltiplas câmeras. Fluxo principal (HD) exibe sempre em alta definição.',
                    value: store.config.defaultStreamMode,
                    items: const [
                      DropdownMenuItem(
                        value: 'sub',
                        child: Text('Subfluxo (Econômico / SD)'),
                      ),
                      DropdownMenuItem(
                        value: 'main',
                        child: Text('Fluxo principal (HD)'),
                      ),
                      DropdownMenuItem(
                        value: 'auto',
                        child: Text('Automático'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        store.updateSettings(defaultStreamMode: value);
                      }
                    },
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
          ],
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
                    'Transfira câmeras, layouts, perfis e preferências. Você escolhe se deseja incluir os dados de acesso.',
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
                        label: const Text('Importar arquivo, QR ou código'),
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
                  leading: const AppLogo(),
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
    final source = await readTransferSource(context);
    if (source != null && context.mounted) {
      await _confirmImport(context, store, source);
    }
  }

  Future<void> _confirmImport(
    BuildContext context,
    AppStore store,
    String source,
  ) async {
    bool profile;
    try {
      final decoded = jsonDecode(TransferCodec.decode(source));
      if (decoded is! Map) throw const FormatException();
      profile = decoded['format'] == AppStore.profileExportFormat;
    } on Object {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Configuração inválida. Confira o arquivo ou copie o código completo.',
          ),
        ),
      );
      return;
    }
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          profile ? 'Adicionar perfis recebidos?' : 'Substituir configurações?',
        ),
        content: Text(
          profile
              ? 'Os perfis e câmeras recebidos serão adicionados. Seus perfis atuais serão mantidos.'
              : 'Esta configuração substituirá câmeras, layouts, preferências, miniaturas e credenciais deste dispositivo.',
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
    bool imported;
    if (profile) {
      final added = await store.importMonitorProfiles(source);
      imported = added != null && added > 0;
      if (imported) {
        imported = await store.applyMonitorProfile(
          store.config.monitorProfiles.last.id,
        );
      }
    } else {
      imported = await store.importConfiguration(source);
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          imported
              ? 'Configuração importada. Você já pode trocar câmeras e editar o layout.'
              : store.message ?? 'O backup não pôde ser importado.',
        ),
      ),
    );
    if (imported) widget.onImported?.call();
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
    final include = await askExportCredentials(context);
    if (include == null) return;
    final content = await store.exportBackup(includeCredentials: include);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) =>
          TransferExportDialog(json: content, includesCredentials: include),
    );
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
        final textScaler = MediaQuery.textScalerOf(context);
        final isLargeText = textScaler.scale(14) > 16;
        final stackVertically = constraints.maxWidth < 680 || isLargeText;

        if (stackVertically) {
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
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              DropdownButton<T>(
                value: value,
                items: items,
                onChanged: onChanged,
              ),
            ],
          ),
        );
      },
    );
  }
}
