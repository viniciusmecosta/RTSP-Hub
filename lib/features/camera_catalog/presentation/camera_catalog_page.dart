import 'dart:async';
import 'dart:typed_data';

import 'camera_preview_dialog.dart';
import 'camera_thumbnail.dart';

import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:uuid/uuid.dart';

import '../../../app/state/app_store.dart';
import '../../discovery/application/stream_quality.dart';
import '../../discovery/data/onvif_discovery_service.dart';
import '../../discovery/domain/rtsp_channel_candidates.dart';
import '../../monitor/application/rtsp_session.dart';
import '../domain/camera_device.dart';
import '../domain/camera_field_validation.dart';
import '../../../shared/design_system/page_frame.dart';
import 'clone_camera_dialog.dart';
import 'network_camera_discovery.dart';

class CameraCatalogPage extends StatelessWidget {
  const CameraCatalogPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    return PageFrame.slivers(
      title: 'Câmeras',
      subtitle: 'Cadastre e organize seus dispositivos RTSP.',
      actions: [
        FilledButton.icon(
          onPressed: () => _edit(context),
          icon: const Icon(Icons.add),
          label: const Text('Adicionar câmera'),
        ),
      ],
      slivers: [
        const SliverToBoxAdapter(
          child: Column(
            children: [NetworkCameraDiscovery(), SizedBox(height: 16)],
          ),
        ),
        if (store.cameras.isEmpty)
          SliverToBoxAdapter(
            child: EmptyPanel(
              icon: Icons.videocam_outlined,
              title: 'Nenhuma câmera cadastrada',
              description:
                  'Adicione uma câmera IP para começar a montar seu monitor.',
              action: FilledButton.icon(
                onPressed: () => _edit(context),
                icon: const Icon(Icons.add),
                label: const Text('Adicionar câmera'),
              ),
            ),
          )
        else
          SliverLayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.crossAxisExtent >= 900
                  ? 3
                  : constraints.crossAxisExtent >= 580
                  ? 2
                  : 1;
              return SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _CameraCard(
                    camera: store.cameras[index],
                    onEdit: () => _edit(context, store.cameras[index]),
                    onClone: () => _clone(context, store, store.cameras[index]),
                    onDelete: () =>
                        _delete(context, store, store.cameras[index]),
                  ),
                  childCount: store.cameras.length,
                ),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  mainAxisExtent: 280,
                ),
              );
            },
          ),
      ],
    );
  }

  Future<void> _clone(
    BuildContext context,
    AppStore store,
    CameraDevice camera,
  ) async {
    final cloned = await CloneCameraDialog.show(
      context,
      camera: camera,
      store: store,
    );
    if (cloned == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Câmera “${camera.name}” clonada com sucesso.')),
      );
    }
  }

  Future<void> _edit(BuildContext context, [CameraDevice? camera]) async {
    final store = AppScope.of(context);
    final password = camera == null
        ? await store.networkDiscoveryPassword()
        : await store.passwordFor(camera);
    final globalPassword = await store.networkDiscoveryPassword();
    if (!context.mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _CameraEditor(
        camera: camera,
        password: password,
        globalPassword: globalPassword,
        store: store,
      ),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Câmera salva com segurança.')),
      );
    }
  }

  Future<void> _delete(
    BuildContext context,
    AppStore store,
    CameraDevice camera,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover câmera?'),
        content: Text(
          '“${camera.name}” será removida do dispositivo e dos layouts.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmed == true) await store.removeCamera(camera.id);
  }
}

class _CameraCard extends StatelessWidget {
  const _CameraCard({
    required this.camera,
    required this.onEdit,
    required this.onClone,
    required this.onDelete,
  });
  final CameraDevice camera;
  final VoidCallback onEdit;
  final VoidCallback onClone;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                CameraThumbnail(cameraId: camera.id),
                Center(
                  child: IconButton.filled(
                    onPressed: () =>
                        CameraPreviewDialog.openSaved(context, store, camera),
                    tooltip: 'Ver vídeo de ${camera.name}',
                    icon: const Icon(Icons.play_arrow),
                  ),
                ),
                const Positioned(
                  left: 12,
                  bottom: 8,
                  child: Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text('Miniatura salva'),
                    avatar: Icon(Icons.photo_outlined, size: 16),
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            title: Text(
              camera.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              camera.host,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: onEdit,
            trailing: PopupMenuButton<String>(
              tooltip: 'Opções da câmera',
              onSelected: (value) => switch (value) {
                'edit' => onEdit(),
                'clone' => onClone(),
                'delete' => onDelete(),
                _ => null,
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Editar câmera')),
                PopupMenuItem(value: 'clone', child: Text('Clonar câmera')),
                PopupMenuItem(value: 'delete', child: Text('Remover')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraEditor extends StatefulWidget {
  const _CameraEditor({
    required this.camera,
    required this.password,
    required this.globalPassword,
    required this.store,
  });
  final CameraDevice? camera;
  final String? password;
  final String? globalPassword;
  final AppStore store;

  @override
  State<_CameraEditor> createState() => _CameraEditorState();
}

class _CameraEditorState extends State<_CameraEditor>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
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
  late bool _useGlobalCredentials;
  bool _busy = false;
  bool _testing = false;
  bool _finding = false;
  bool _searchRecorderChannels = false;
  bool _cancelFinding = false;
  String _findingStage = '';
  String? _probeMessage;
  bool? _probeSucceeded;
  RtspSession? _probe;
  Completer<bool>? _probeCompleter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final camera = widget.camera;
    _useGlobalCredentials = camera?.useGlobalCredentials ?? true;
    _name = TextEditingController(text: camera?.name ?? '');
    _host = TextEditingController(text: camera?.host ?? '');
    _port = TextEditingController(text: camera?.port?.toString() ?? '');
    _username = TextEditingController(
      text: _useGlobalCredentials
          ? widget.store.config.defaultUser
          : camera?.username ?? widget.store.config.defaultUser,
    );
    _password = TextEditingController(
      text: _useGlobalCredentials
          ? widget.globalPassword ?? ''
          : widget.password ?? '',
    );
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
      final probe = _probe;
      if (probe != null) unawaited(probe.disposeSession());
      if (!(_probeCompleter?.isCompleted ?? true)) {
        _probeCompleter!.complete(false);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelFinding = true;
    _mainPath.removeListener(_onMainPathChanged);
    final probe = _probe;
    if (probe != null) {
      probe.removeListener(_refreshProbe);
      probe.firstFrameRendered.removeListener(_checkProbe);
      probe.error.removeListener(_checkProbe);
      unawaited(probe.disposeSession());
    }
    if (!(_probeCompleter?.isCompleted ?? true)) {
      _probeCompleter!.complete(false);
    }
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
    final fields = Column(
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Usar credenciais globais'),
          subtitle: const Text('Compartilha o usuário e a senha padrão.'),
          value: _useGlobalCredentials,
          onChanged: _busy || _testing || _finding
              ? null
              : (enabled) => setState(() {
                  _useGlobalCredentials = enabled;
                  if (enabled) {
                    _username.text = widget.store.config.defaultUser;
                    _password.text = widget.globalPassword ?? '';
                  } else {
                    _username.text = widget.camera?.username ?? '';
                    _password.text = widget.password ?? '';
                  }
                }),
        ),
        TextFormField(
          controller: _name,
          decoration: const InputDecoration(
            labelText: 'Nome',
            hintText: 'Ex.: Entrada principal',
          ),
          maxLength: 80,
          buildCounter:
              (_, {required currentLength, required isFocused, maxLength}) =>
                  null,
          validator: (value) => (value?.trim().length ?? 0) > 80
              ? 'Use até 80 caracteres.'
              : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _host,
          decoration: const InputDecoration(
            labelText: 'Endereço IP ou host',
            hintText: '192.168.1.50',
          ),
          keyboardType: TextInputType.url,
          validator: (value) {
            final host = value?.trim() ?? '';
            final error = CameraFieldValidation.hostError(host);
            if (error != null) return error;
            final port =
                int.tryParse(_port.text.trim()) ??
                widget.store.config.defaultPort;
            final enteredPath = _mainPath.text.trim().isEmpty
                ? widget.store.config.defaultPath
                : _mainPath.text.trim();
            final path = enteredPath.startsWith('/')
                ? enteredPath
                : '/$enteredPath';
            final duplicate = widget.store.cameras.any(
              (camera) =>
                  camera.id != widget.camera?.id &&
                  camera.host.toLowerCase() == host.toLowerCase() &&
                  camera.effectivePort(widget.store.config.defaultPort) ==
                      port &&
                  camera.mainPath == path,
            );
            return duplicate
                ? 'Esse endereço, porta e caminho já estão cadastrados.'
                : null;
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _port,
                decoration: InputDecoration(
                  labelText: 'Porta',
                  hintText: '${widget.store.config.defaultPort}',
                  helperText: 'Vazio usa a porta padrão',
                ),
                keyboardType: TextInputType.number,
                buildCounter:
                    (
                      _, {
                      required currentLength,
                      required isFocused,
                      maxLength,
                    }) => null,
                validator: (value) =>
                    CameraFieldValidation.portError(value ?? ''),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _username,
                enabled: !_useGlobalCredentials,
                decoration: const InputDecoration(labelText: 'Usuário'),
                maxLength: 128,
                buildCounter:
                    (
                      _, {
                      required currentLength,
                      required isFocused,
                      maxLength,
                    }) => null,
                validator: (value) => (value?.length ?? 0) > 128
                    ? 'Use até 128 caracteres.'
                    : null,
                textInputAction: TextInputAction.next,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _password,
          enabled: !_useGlobalCredentials,
          decoration: InputDecoration(
            labelText: widget.camera == null ? 'Senha (opcional)' : 'Senha',
            helperText: widget.camera != null && widget.password == null
                ? 'Não foi possível ler a senha salva; informe-a novamente.'
                : 'Armazenada no cofre seguro do dispositivo.',
            suffixIcon: IconButton(
              onPressed: () => setState(() => _obscure = !_obscure),
              icon: Icon(
                _obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
          obscureText: _obscure,
          maxLength: 1024,
          buildCounter:
              (_, {required currentLength, required isFocused, maxLength}) =>
                  null,
          validator: (value) =>
              (value?.length ?? 0) > 1024 ? 'Use até 1024 caracteres.' : null,
          enableSuggestions: false,
          autocorrect: false,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _mainPath,
          decoration: InputDecoration(
            labelText: 'Canais',
            hintText: widget.store.config.defaultPath,
            helperText: _savedPaths.isEmpty
                ? 'Vazio usa o canal padrão'
                : 'Selecione na lista suspensa/opções ou informe o canal',
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_mainPath.text.trim().isNotEmpty &&
                    !_savedPaths.contains(_mainPath.text.trim()))
                  IconButton(
                    icon: const Icon(Icons.bookmark_add_outlined),
                    tooltip: 'Salvar canal na lista',
                    onPressed: () {
                      final error = CameraFieldValidation.pathError(
                        _mainPath.text.trim(),
                      );
                      if (error == null) {
                        setState(() {
                          _savedPaths.add(_mainPath.text.trim());
                        });
                      }
                    },
                  ),
                if (_savedPaths.isNotEmpty)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.arrow_drop_down),
                    tooltip: 'Canais salvos',
                    onSelected: (path) {
                      setState(() {
                        _mainPath.text = path;
                      });
                    },
                    itemBuilder: (context) => _savedPaths
                        .map(
                          (path) => PopupMenuItem<String>(
                            value: path,
                            child: Row(
                              children: [
                                Icon(
                                  path == _mainPath.text.trim()
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  size: 16,
                                  color: path == _mainPath.text.trim()
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    path,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
              ],
            ),
          ),
          validator: (value) => (value ?? '').trim().isEmpty
              ? null
              : CameraFieldValidation.pathError(value ?? ''),
        ),
        if (_savedPaths.isNotEmpty) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ..._savedPaths.map((path) {
                  final isSelected = path == _mainPath.text.trim();
                  return InputChip(
                    selected: isSelected,
                    label: Text(path, style: const TextStyle(fontSize: 11)),
                    onSelected: (_) {
                      setState(() {
                        _mainPath.text = path;
                      });
                    },
                    onDeleted: _savedPaths.length > 1
                        ? () {
                            setState(() {
                              _savedPaths.remove(path);
                            });
                          }
                        : null,
                    deleteButtonTooltipMessage: 'Remover canal salvo',
                  );
                }),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        TextFormField(
          controller: _subPath,
          decoration: const InputDecoration(
            labelText: 'Caminho RTSP secundário (opcional)',
          ),
          validator: (value) =>
              CameraFieldValidation.pathError(value ?? '', optional: true),
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Pesquisar canais de gravador'),
          subtitle: const Text(
            'Se ONVIF não responder, teste até 16 canais RTSP. Para câmera IP, deixe desligado.',
          ),
          value: _searchRecorderChannels,
          onChanged: _finding || _testing
              ? null
              : (value) => setState(() => _searchRecorderChannels = value),
        ),
      ],
    );
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.camera == null
                            ? 'Adicionar câmera'
                            : 'Editar câmera',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      tooltip: 'Fechar',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_probe?.videoController != null)
                  Offstage(
                    child: SizedBox.square(
                      dimension: 2,
                      child: Video(
                        controller: _probe!.videoController!,
                        controls: NoVideoControls,
                      ),
                    ),
                  ),
                Flexible(child: SingleChildScrollView(child: fields)),
                if (_finding) ...[
                  const SizedBox(height: 12),
                  _ProbeResult(message: _findingStage, succeeded: null),
                ],
                if (_probeMessage != null && !_finding) ...[
                  const SizedBox(height: 12),
                  _ProbeResult(
                    message: _probeMessage!,
                    succeeded: _probeSucceeded,
                  ),
                ],
                const SizedBox(height: 16),
                Wrap(
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
                      onPressed: _busy || _testing || _finding
                          ? null
                          : _testStream,
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
                ),
              ],
            ),
          ),
        ),
      ),
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
      useGlobalCredentials: _useGlobalCredentials,
    );
    setState(() => _testing = true);
    final identity = _captureIdentity;
    final thumbnail = await showDialog<Uint8List>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CameraPreviewDialog(
        camera: camera,
        password: _password.text.isEmpty ? null : _password.text,
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
    _useGlobalCredentials.toString(),
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
    final username = _username.text.trim();
    final password = _password.text;
    setState(() {
      _finding = true;
      _cancelFinding = false;
      _probeMessage = null;
      _findingStage = 'Consultando ONVIF em $host';
    });
    final found = <_FoundChannel>[];
    try {
      final device = await OnvifDiscoveryService().loadProfiles(
        OnvifProbeDevice(
          sourceAddress: host,
          deviceServiceUri: Uri(
            scheme: 'http',
            host: host,
            path: '/onvif/device_service',
          ),
          name: null,
        ),
        username: username,
        password: password,
        isCancelled: () => _cancelFinding,
      );
      for (final pair in OnvifStreamPair.group(device?.profiles ?? const [])) {
        String path(Uri uri) => uri.hasQuery
            ? '${uri.path}?${uri.query}'
            : (uri.path.isEmpty ? '/' : uri.path);
        found.add(
          _FoundChannel(
            number: found.length + 1,
            mainPath: path(pair.main.streamUri),
            mainQuality: pair.main.quality,
            subPath: pair.sub == null ? null : path(pair.sub!.streamUri),
            subQuality: pair.sub?.quality,
          ),
        );
      }
      if (found.isEmpty) {
        await _probeCandidates(host, port, username, password, found);
      }
    } on Object {
      // Falhas de rede apenas encerram a busca; o resultado vazio é exibido.
    }
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
    final chosen = await showDialog<(_FoundChannel, bool)>(
      context: context,
      builder: (context) => _FoundChannelsDialog(channels: found),
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

  Future<void> _probeCandidates(
    String host,
    int port,
    String username,
    String password,
    List<_FoundChannel> found,
  ) async {
    final lastChannel = _searchRecorderChannels ? 16 : 1;
    for (var channel = 1; channel <= lastChannel; channel++) {
      if (_cancelFinding || !mounted) return;
      setState(() => _findingStage = 'Testando canal $channel em $host');
      String? mainPath;
      String? mainQuality;
      for (final path in RtspChannelCandidates.mainForChannel(channel)) {
        mainQuality = await _probeQuality(host, port, username, password, path);
        if (_cancelFinding) return;
        if (mainQuality != null) {
          mainPath = path;
          break;
        }
      }
      if (mainPath == null) return;
      String? subPath;
      String? subQuality;
      for (final path in RtspChannelCandidates.subForChannel(channel)) {
        subQuality = await _probeQuality(host, port, username, password, path);
        if (_cancelFinding) return;
        if (subQuality != null) {
          subPath = path;
          break;
        }
      }
      if (subQuality != null &&
          StreamSignature.sameKnownResolution(mainQuality!, subQuality)) {
        subPath = null;
        subQuality = null;
      }
      found.add(
        _FoundChannel(
          number: channel,
          mainPath: mainPath,
          mainQuality: mainQuality!,
          subPath: subPath,
          subQuality: subQuality,
        ),
      );
    }
  }

  Future<String?> _probeQuality(
    String host,
    int port,
    String username,
    String password,
    String path,
  ) async {
    final session = RtspSession(
      camera: CameraDevice(
        id: 'channel-search',
        name: host,
        host: host,
        port: port,
        username: username,
        mainPath: path,
      ),
      password: password.isEmpty ? null : password,
      defaultPort: port,
      bufferMs: 120,
      useMainStream: true,
      firstFrameTimeout: const Duration(milliseconds: 1500),
      retryEnabled: false,
    );
    _probe = session;
    session.addListener(_refreshProbe);
    if (mounted) setState(() {});
    await WidgetsBinding.instance.endOfFrame;
    String? quality;
    if (mounted && !_cancelFinding) {
      await session.start();
      if (session.firstFrameRendered.value) {
        quality = describeStreamQuality(session);
      }
    }
    session.removeListener(_refreshProbe);
    await session.disposeSession();
    if (identical(_probe, session)) {
      _probe = null;
      if (mounted) setState(() {});
    }
    return quality;
  }

  void _refreshProbe() {
    if (mounted) setState(() {});
  }

  void _checkProbe() {
    final completer = _probeCompleter;
    final session = _probe;
    if (completer == null || session == null || completer.isCompleted) return;
    if (session.firstFrameRendered.value) {
      completer.complete(true);
    } else if (session.error.value != null) {
      completer.complete(false);
    }
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
      port: _port.text,
      username: _username.text,
      password: _password.text,
      mainPath: _mainPath.text,
      subPath: _subPath.text,
      useGlobalCredentials: _useGlobalCredentials,
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

class _ProbeResult extends StatelessWidget {
  const _ProbeResult({required this.message, required this.succeeded});

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

class _FoundChannel {
  const _FoundChannel({
    required this.number,
    required this.mainPath,
    required this.mainQuality,
    required this.subPath,
    required this.subQuality,
  });

  final int number;
  final String mainPath;
  final String mainQuality;
  final String? subPath;
  final String? subQuality;
}

class _FoundChannelsDialog extends StatelessWidget {
  const _FoundChannelsDialog({required this.channels});

  final List<_FoundChannel> channels;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Canais encontrados'),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: MediaQuery.sizeOf(context).height * 0.72,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final channel in channels)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Canal ${channel.number}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Principal: ${channel.mainQuality.isEmpty ? channel.mainPath : channel.mainQuality}',
                      ),
                      if (channel.subPath != null)
                        Text(
                          'Subfluxo: ${channel.subQuality?.isNotEmpty == true ? channel.subQuality : channel.subPath}',
                        ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.tonal(
                            onPressed: () =>
                                Navigator.pop(context, (channel, false)),
                            child: Text(
                              channel.subPath == null
                                  ? 'Usar'
                                  : 'Usar principal + sub',
                            ),
                          ),
                          if (channel.subPath != null)
                            OutlinedButton(
                              onPressed: () =>
                                  Navigator.pop(context, (channel, true)),
                              child: const Text('Usar só subfluxo'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}
