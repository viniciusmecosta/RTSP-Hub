import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';

import '../../../app/state/app_store.dart';
import '../../../shared/design_system/page_frame.dart';
import '../../../shared/platform/windows_startup_service.dart';
import '../../../shared/platform/linux_startup_service.dart';
import '../../camera_catalog/domain/camera_field_validation.dart';
import '../domain/performance_preset.dart';

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
    if (!context.mounted) return;
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
      subtitle: 'Aparência e uso de recursos neste dispositivo.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                const Divider(height: 1),
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
                  title: const Text('Buffer de rede'),
                  subtitle: Text(
                    'Perfil ${store.config.bufferMs} · valores menores limitam a memória do fluxo e podem causar pausas em redes instáveis.',
                  ),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.lock_outline),
                  title: Text('Credenciais protegidas'),
                  subtitle: Text(
                    'Senhas são guardadas no cofre seguro do sistema e nunca no arquivo de configuração.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _GlobalConnectionCard(),
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
                    'O backup contém câmeras, layouts e preferências. Senhas são excluídas e permanecem apenas no cofre deste dispositivo.',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _exportBackup(context, store),
                        icon: const Icon(Icons.save_alt_outlined),
                        label: const Text('Exportar backup'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => _importBackup(context, store),
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
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                '${PerformancePreset.fromId(store.config.resourceMode).description} Todas as câmeras da grade são exibidas simultaneamente.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
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
      if (await backup.length() > 5 * 1024 * 1024) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('O backup excede o limite de 5 MB.')),
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
          'Câmeras, layouts e preferências atuais serão substituídos. As senhas salvas neste dispositivo não serão exportadas nem apagadas.',
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
              ? 'Configurações importadas. Senhas ausentes devem ser informadas novamente.'
              : store.message ?? 'O backup não pôde ser importado.',
        ),
      ),
    );
  }

  Future<void> _exportBackup(BuildContext context, AppStore store) async {
    final content = store.exportConfiguration();
    final now = DateTime.now();
    final filename =
        'rtsp-hub-backup-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}.json';
    try {
      String? path;
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        if (Platform.isAndroid) {
          final directory = await getDirectoryPath(
            confirmButtonText: 'Salvar backup nesta pasta',
          );
          if (directory == null) return;
          path =
              '${Directory(directory).path}${Platform.pathSeparator}$filename';
        } else {
          await Clipboard.setData(ClipboardData(text: content));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Backup copiado para a área de transferência.'),
              ),
            );
          }
          return;
        }
      } else if (!kIsWeb &&
          (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
        final location = await getSaveLocation(
          acceptedTypeGroups: const [
            XTypeGroup(label: 'Arquivo JSON', extensions: ['json']),
          ],
          suggestedName: filename,
        );
        path = location?.path;
      }
      if (path == null) return;
      await File(path).writeAsString(content, flush: true);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Backup salvo em $path.')));
      }
    } on Object {
      if (context.mounted) {
        await Clipboard.setData(ClipboardData(text: content));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível salvar o arquivo; o backup foi copiado.',
            ),
          ),
        );
      }
    }
  }
}

class _GlobalConnectionCard extends StatefulWidget {
  const _GlobalConnectionCard();

  @override
  State<_GlobalConnectionCard> createState() => _GlobalConnectionCardState();
}

class _GlobalConnectionCardState extends State<_GlobalConnectionCard> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _port = TextEditingController();
  final _channel = TextEditingController();
  bool _loaded = false;
  bool _saving = false;
  bool _obscure = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    final store = AppScope.of(context);
    _username.text = store.config.defaultUser;
    _port.text = '${store.config.defaultPort}';
    _channel.text = store.config.defaultPath;
    unawaited(
      store.networkDiscoveryPassword().then((password) {
        if (mounted && password != null) _password.text = password;
      }),
    );
  }

  @override
  void dispose() {
    for (final controller in [_username, _password, _port, _channel]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final store = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    final path = _channel.text.trim();
    await store.updateSettings(
      defaultPort: int.parse(_port.text.trim()),
      defaultPath: path.startsWith('/') ? path : '/$path',
    );
    final saved = await store.saveNetworkDiscoveryCredentials(
      username: _username.text.trim(),
      password: _password.text,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? 'Conexão padrão salva. Novas câmeras sem esses dados usarão estes valores.'
              : store.message ?? 'Não foi possível salvar a conexão padrão.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fields = <Widget>[
      TextFormField(
        controller: _username,
        decoration: const InputDecoration(labelText: 'Usuário padrão'),
        validator: (value) =>
            (value?.length ?? 0) > 128 ? 'Use até 128 caracteres.' : null,
      ),
      TextFormField(
        controller: _password,
        obscureText: _obscure,
        autocorrect: false,
        enableSuggestions: false,
        decoration: InputDecoration(
          labelText: 'Senha padrão',
          suffixIcon: IconButton(
            tooltip: _obscure ? 'Mostrar senha' : 'Ocultar senha',
            onPressed: () => setState(() => _obscure = !_obscure),
            icon: Icon(
              _obscure
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
          ),
        ),
        validator: (value) =>
            (value?.length ?? 0) > 1024 ? 'Use até 1024 caracteres.' : null,
      ),
      TextFormField(
        controller: _port,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Porta padrão'),
        validator: (value) => (value ?? '').trim().isEmpty
            ? 'Informe a porta.'
            : CameraFieldValidation.portError(value ?? ''),
      ),
      TextFormField(
        controller: _channel,
        decoration: const InputDecoration(
          labelText: 'Canal padrão',
          hintText: '/Streaming/Channels/101',
        ),
        validator: (value) => CameraFieldValidation.pathError(value ?? ''),
      ),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Conexão padrão',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              const Text(
                'Usada quando uma câmera é cadastrada sem senha, porta ou canal. A senha fica no cofre seguro do dispositivo.',
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 640 ? 2 : 1;
                  final width =
                      (constraints.maxWidth - (columns - 1) * 12) / columns;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final field in fields)
                        SizedBox(width: width, child: field),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Salvar conexão padrão'),
                ),
              ),
            ],
          ),
        ),
      ),
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
