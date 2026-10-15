import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../app/state/app_store.dart';
import '../application/camera_channel_prober.dart';
import '../domain/camera_device.dart';
import '../domain/camera_field_validation.dart';
import '../domain/found_channel.dart';
import 'camera_preview_dialog.dart';
import 'widgets/camera_auth_fields.dart';
import 'widgets/camera_network_fields.dart';
import 'widgets/camera_path_fields.dart';
import 'widgets/found_channels_dialog.dart';
import 'widgets/probe_result_view.dart';

class CameraEditorDialog extends StatefulWidget {
  const CameraEditorDialog({
    required this.camera,
    required this.password,
    required this.globalPassword,
    required this.store,
    super.key,
  });

  final CameraDevice? camera;
  final String? password;
  final String? globalPassword;
  final AppStore store;

  @override
  State<CameraEditorDialog> createState() => _CameraEditorDialogState();
}

class _CameraEditorDialogState extends State<CameraEditorDialog>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  late final CameraChannelProber _prober;
  late final TextEditingController _name;
  late final TextEditingController _host;
  late final TextEditingController _port;
  late final TextEditingController _username;
  late final TextEditingController _password;
  late final TextEditingController _mainPath;
  late final TextEditingController _subPath;
  late List<String> _savedPaths;
  Uint8List? _thumbnail;
  String? _thumbnailIdentity;
  bool _obscure = true;
  bool _portOverride = false;
  bool _busy = false;
  bool _testing = false;
  bool _finding = false;
  bool _searchRecorderChannels = false;
  bool _cancelFinding = false;
  String _findingStage = '';
  String? _probeMessage;
  bool? _probeSucceeded;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _prober = CameraChannelProber();
    final camera = widget.camera;
    _name = TextEditingController(text: camera?.name ?? '');
    _host = TextEditingController(text: camera?.host ?? '');
    _portOverride = camera?.port != null;
    _port = TextEditingController(
      text: '${camera?.port ?? widget.store.config.defaultPort}',
    );
    _username = TextEditingController(
      text: camera?.useGlobalCredentials == true ? '' : camera?.username ?? '',
    );
    _password = TextEditingController(text: widget.password ?? '');
    _mainPath = TextEditingController(text: camera?.mainPath ?? '');
    _subPath = TextEditingController(text: camera?.subPath ?? '');
    final initialPaths = <String>[
      if (camera != null && camera.mainPath.trim().isNotEmpty)
        camera.mainPath.trim(),
      if (camera != null && camera.subPath.trim().isNotEmpty)
        camera.subPath.trim(),
      ...?camera?.savedPaths.map((p) => p.trim()).where((p) => p.isNotEmpty),
    ];
    _savedPaths = initialPaths.toSet().toList();
    _mainPath.addListener(_onMainPathChanged);
  }

  void _onMainPathChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_prober.dispose());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelFinding = true;
    _mainPath.removeListener(_onMainPathChanged);
    unawaited(_prober.dispose());
    for (final controller in [
      _name,
      _host,
      _port,
      _username,
      _password,
      _mainPath,
      _subPath,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Dialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 20,
        vertical: compact ? 16 : 24,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 760),
        child: Padding(
          padding: EdgeInsets.all(compact ? 16 : 28),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(context),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_thumbnail != null) ...[
                          _buildThumbnail(),
                          const SizedBox(height: 16),
                        ],
                        const Text(
                          'Preencha apenas o que for diferente da conexão global. Cada campo vazio usa seu próprio padrão.',
                        ),
                        const SizedBox(height: 18),
                        CameraNetworkFields(
                          nameController: _name,
                          hostController: _host,
                          portController: _port,
                          mainPathController: _mainPath,
                          store: widget.store,
                          editingCamera: widget.camera,
                          onPortChanged: (_) => _portOverride = true,
                          onPortReset: () => setState(() {
                            _portOverride = false;
                            _port.text = '${widget.store.config.defaultPort}';
                          }),
                        ),
                        const SizedBox(height: 12),
                        CameraAuthFields(
                          usernameController: _username,
                          passwordController: _password,
                          defaultUser: widget.store.config.defaultUser,
                          obscurePassword: _obscure,
                          onToggleObscure: () => setState(() => _obscure = !_obscure),
                        ),
                        const SizedBox(height: 12),
                        CameraPathFields(
                          mainPathController: _mainPath,
                          subPathController: _subPath,
                          defaultPath: widget.store.config.defaultPath,
                          defaultSubPath: widget.store.config.defaultSubPath,
                          savedPaths: _savedPaths,
                          onAddSavedPath: (path) => setState(() => _savedPaths.add(path)),
                          onSelectSavedPath: (path) => setState(() => _mainPath.text = path),
                          onRemoveSavedPath: (path) => setState(() => _savedPaths.remove(path)),
                          searchRecorderChannels: _searchRecorderChannels,
                          onToggleSearchRecorderChannels: (v) =>
                              setState(() => _searchRecorderChannels = v),
                          isProbingOrTesting: _finding || _testing,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_finding) ...[
                  const SizedBox(height: 12),
                  ProbeResultView(message: _findingStage, succeeded: null),
                ],
                if (_probeMessage != null && !_finding) ...[
                  const SizedBox(height: 12),
                  ProbeResultView(
                    message: _probeMessage!,
                    succeeded: _probeSucceeded,
                  ),
                ],
                const SizedBox(height: 16),
                _buildActions(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            widget.camera == null ? 'Adicionar câmera' : 'Editar câmera',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        IconButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          icon: const Icon(Icons.close),
          tooltip: 'Fechar',
        ),
      ],
    );
  }

  Widget _buildThumbnail() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 140,
            child: Image.memory(
              _thumbnail!,
              fit: BoxFit.cover,
              cacheWidth: 640,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Miniatura capturada. Ela aparecerá no catálogo e nos layouts.',
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: _busy || _testing
              ? null
              : _finding
              ? () => setState(() => _cancelFinding = true)
              : _findChannels,
          icon: _finding
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.manage_search_outlined),
          label: Text(_finding ? 'Parar busca' : 'Achar canais'),
        ),
        OutlinedButton.icon(
          onPressed: _busy || _testing || _finding ? null : _testStream,
          icon: _testing
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.play_circle_outline),
          label: Text(_testing ? 'Testando…' : 'Testar vídeo'),
        ),
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _busy || _testing || _finding ? null : _save,
          icon: _busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: const Text('Salvar'),
        ),
      ],
    );
  }

  Future<void> _testStream() async {
    if (!_formKey.currentState!.validate()) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final host = _host.text.trim();
    final enteredPath = _mainPath.text.trim().isEmpty
        ? widget.store.config.defaultPath
        : _mainPath.text.trim();
    final camera = CameraDevice(
      id: widget.camera?.id ?? const Uuid().v4(),
      name: _name.text.trim().isEmpty ? host : _name.text.trim(),
      host: host,
      port: _port.text.trim().isEmpty ? null : int.tryParse(_port.text.trim()),
      username: _username.text.trim(),
      mainPath: enteredPath.startsWith('/') ? enteredPath : '/$enteredPath',
      subPath: _subPath.text.trim(),
      useGlobalCredentials: false,
    );
    setState(() => _testing = true);
    final identity = _captureIdentity;
    final thumbnail = await showDialog<Uint8List>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CameraPreviewDialog(
        camera: widget.store.resolveCamera(camera),
        password: _password.text.isEmpty
            ? widget.globalPassword
            : _password.text,
        defaultPort: widget.store.config.defaultPort,
        bufferMs: widget.store.config.bufferMs,
        captureOnly: _busy,
      ),
    );
    if (!mounted) return;
    setState(() {
      _testing = false;
      _thumbnail = thumbnail;
      _thumbnailIdentity = thumbnail == null ? null : identity;
    });
  }

  String get _captureIdentity => [
    _host.text,
    _port.text,
    _username.text,
    _password.text,
    _mainPath.text,
    _portOverride.toString(),
  ].join('\u0000');

  Future<void> _findChannels() async {
    final host = _host.text.trim();
    final hostError = CameraFieldValidation.hostError(host);
    final portError = CameraFieldValidation.portError(_port.text);
    if (hostError != null || portError != null) {
      _formKey.currentState!.validate();
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    final port =
        int.tryParse(_port.text.trim()) ?? widget.store.config.defaultPort;
    final username = _username.text.trim().isEmpty
        ? widget.store.config.defaultUser
        : _username.text.trim();
    final password = _password.text.isEmpty
        ? widget.globalPassword ?? ''
        : _password.text;
    setState(() {
      _finding = true;
      _cancelFinding = false;
      _probeMessage = null;
      _findingStage = 'Consultando ONVIF em $host';
    });
    final found = await _prober.findChannels(
      host: host,
      port: port,
      username: username,
      password: password,
      defaultPath: _mainPath.text.trim().isEmpty
          ? widget.store.config.defaultPath
          : _mainPath.text.trim(),
      searchRecorderChannels: _searchRecorderChannels,
      isCancelled: () => _cancelFinding,
      onProgress: (stage) {
        if (mounted) setState(() => _findingStage = stage);
      },
    );
    if (!mounted) return;
    setState(() => _finding = false);
    if (_cancelFinding) return;
    if (found.isEmpty) {
      setState(() {
        _probeMessage =
            'Nenhum canal de vídeo respondeu. Confira IP, porta e credenciais.';
        _probeSucceeded = false;
      });
      return;
    }
    final chosen = await showDialog<(FoundChannel, bool)>(
      context: context,
      builder: (context) => FoundChannelsDialog(channels: found),
    );
    if (chosen == null || !mounted) return;
    final (channel, useSubOnly) = chosen;
    setState(() {
      _mainPath.text = useSubOnly ? channel.subPath! : channel.mainPath;
      _subPath.text = useSubOnly ? '' : channel.subPath ?? '';
      for (final ch in found) {
        if (!_savedPaths.contains(ch.mainPath)) _savedPaths.add(ch.mainPath);
        if (ch.subPath != null &&
            ch.subPath!.isNotEmpty &&
            !_savedPaths.contains(ch.subPath!)) {
          _savedPaths.add(ch.subPath!);
        }
      }
      _probeMessage =
          'Canal ${channel.number} selecionado: ${useSubOnly ? channel.subQuality : channel.mainQuality}.';
      _probeSucceeded = true;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    if (_thumbnail == null || _thumbnailIdentity != _captureIdentity) {
      await _testStream();
      if (!mounted) return;
    }
    final currentMain = _mainPath.text.trim();
    if (currentMain.isNotEmpty && !_savedPaths.contains(currentMain)) {
      _savedPaths.add(currentMain);
    }
    final saved = await widget.store.saveCamera(
      id: widget.camera?.id ?? '',
      name: _name.text,
      host: _host.text,
      port: _portOverride ? _port.text : '',
      username: _username.text,
      password: _password.text,
      mainPath: _mainPath.text,
      subPath: _subPath.text,
      useGlobalCredentials: false,
      savedPaths: _savedPaths,
      thumbnail: _thumbnail,
    );
    if (!mounted) return;
    if (saved) {
      Navigator.pop(context, true);
      return;
    }
    final message = widget.store.message;
    if (message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
    setState(() => _busy = false);
  }
}
