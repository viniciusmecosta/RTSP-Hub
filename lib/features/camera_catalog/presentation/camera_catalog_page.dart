import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:uuid/uuid.dart';

import '../../../app/state/app_store.dart';
import '../../monitor/application/rtsp_session.dart';
import '../domain/camera_device.dart';
import '../domain/camera_field_validation.dart';
import '../../../shared/design_system/page_frame.dart';

class CameraCatalogPage extends StatelessWidget {
  const CameraCatalogPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    return PageFrame(
      title: 'Câmeras',
      subtitle: 'Cadastre e organize seus dispositivos RTSP.',
      actions: [
        FilledButton.icon(
          onPressed: () => _edit(context),
          icon: const Icon(Icons.add),
          label: const Text('Adicionar câmera'),
        ),
      ],
      child: store.cameras.isEmpty
          ? EmptyPanel(
              icon: Icons.videocam_outlined,
              title: 'Nenhuma câmera cadastrada',
              description:
                  'Adicione uma câmera IP para começar a montar seu monitor.',
              action: FilledButton.icon(
                onPressed: () => _edit(context),
                icon: const Icon(Icons.add),
                label: const Text('Adicionar câmera'),
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 900
                    ? 3
                    : constraints.maxWidth >= 580
                    ? 2
                    : 1;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: store.cameras.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    mainAxisExtent: 158,
                  ),
                  itemBuilder: (context, index) => _CameraCard(
                    camera: store.cameras[index],
                    onEdit: () => _edit(context, store.cameras[index]),
                    onDelete: () =>
                        _delete(context, store, store.cameras[index]),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _edit(BuildContext context, [CameraDevice? camera]) async {
    final store = AppScope.of(context);
    final password = camera == null ? null : await store.passwordFor(camera);
    if (!context.mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _CameraEditor(camera: camera, password: password, store: store),
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
    required this.onDelete,
  });
  final CameraDevice camera;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.videocam_outlined, color: color.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    camera.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${camera.host}:${camera.port ?? 554}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    camera.mainPath,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Editar')),
                PopupMenuItem(value: 'delete', child: Text('Remover')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraEditor extends StatefulWidget {
  const _CameraEditor({
    required this.camera,
    required this.password,
    required this.store,
  });
  final CameraDevice? camera;
  final String? password;
  final AppStore store;

  @override
  State<_CameraEditor> createState() => _CameraEditorState();
}

class _CameraEditorState extends State<_CameraEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _host;
  late final TextEditingController _port;
  late final TextEditingController _username;
  late final TextEditingController _password;
  late final TextEditingController _mainPath;
  late final TextEditingController _subPath;
  bool _obscure = true;
  bool _busy = false;
  bool _testing = false;
  String? _probeMessage;
  RtspSession? _probe;
  Completer<bool>? _probeCompleter;

  @override
  void initState() {
    super.initState();
    final camera = widget.camera;
    _name = TextEditingController(text: camera?.name ?? '');
    _host = TextEditingController(text: camera?.host ?? '');
    _port = TextEditingController(text: camera?.port?.toString() ?? '');
    _username = TextEditingController(
      text: camera?.username ?? widget.store.config.defaultUser,
    );
    _password = TextEditingController(text: widget.password ?? '');
    _mainPath = TextEditingController(
      text: camera?.mainPath ?? widget.store.config.defaultPath,
    );
    _subPath = TextEditingController(text: camera?.subPath ?? '');
  }

  @override
  void dispose() {
    final probe = _probe;
    if (probe != null) {
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
        TextFormField(
          controller: _name,
          decoration: const InputDecoration(
            labelText: 'Nome',
            hintText: 'Ex.: Entrada principal',
          ),
          maxLength: 80,
          validator: (value) => (value?.trim().length ?? 0) > 80
              ? 'Use até 80 caracteres.'
              : null,
        ),
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
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _port,
                decoration: const InputDecoration(
                  labelText: 'Porta',
                  hintText: '554',
                ),
                keyboardType: TextInputType.number,
                validator: (value) =>
                    CameraFieldValidation.portError(value ?? ''),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _username,
                decoration: const InputDecoration(labelText: 'Usuário'),
                maxLength: 128,
                validator: (value) => (value?.length ?? 0) > 128
                    ? 'Use até 128 caracteres.'
                    : null,
                textInputAction: TextInputAction.next,
              ),
            ),
          ],
        ),
        TextFormField(
          controller: _password,
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
          validator: (value) =>
              (value?.length ?? 0) > 1024 ? 'Use até 1024 caracteres.' : null,
          enableSuggestions: false,
          autocorrect: false,
        ),
        TextFormField(
          controller: _mainPath,
          decoration: const InputDecoration(
            labelText: 'Caminho RTSP principal',
            hintText: '/Streaming/Channels/101',
          ),
          validator: (value) => CameraFieldValidation.pathError(value ?? ''),
        ),
        TextFormField(
          controller: _subPath,
          decoration: const InputDecoration(
            labelText: 'Caminho RTSP secundário (opcional)',
          ),
          validator: (value) =>
              CameraFieldValidation.pathError(value ?? '', optional: true),
        ),
      ],
    );
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 760),
        child: Padding(
          padding: EdgeInsets.all(compact ? 20 : 28),
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
                if (_probeMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(
                      children: [
                        Icon(
                          _probeMessage!.startsWith('Fluxo validado')
                              ? Icons.check_circle_outline
                              : Icons.info_outline,
                          size: 18,
                          color: _probeMessage!.startsWith('Fluxo validado')
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_probeMessage!)),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _busy || _testing ? null : _testStream,
                      icon: _testing
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.play_circle_outline),
                      label: Text(_testing ? 'Testando…' : 'Testar fluxo'),
                    ),
                    TextButton(
                      onPressed: _busy ? null : () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                    FilledButton.icon(
                      onPressed: _busy || _testing ? null : _save,
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
    );
    final session = RtspSession(
      camera: camera,
      password: _password.text.isEmpty ? null : _password.text,
      defaultPort: widget.store.config.defaultPort,
      bufferMs: widget.store.config.bufferMs,
      useMainStream: true,
    );
    final completer = Completer<bool>();
    _probe = session;
    _probeCompleter = completer;
    _probeMessage = 'Conectando e aguardando o primeiro quadro…';
    session.firstFrameRendered.addListener(_checkProbe);
    session.error.addListener(_checkProbe);
    setState(() => _testing = true);
    unawaited(session.start());
    final succeeded = await completer.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () => false,
    );
    if (!mounted) return;
    final failure = session.error.value;
    setState(() {
      _probeMessage = succeeded
          ? 'Fluxo validado: primeiro quadro recebido.'
          : failure == null
          ? 'Tempo esgotado. Confira a rota, a rede e as credenciais.'
          : 'Não foi possível abrir o fluxo: $failure';
      _testing = false;
      _probe = null;
      _probeCompleter = null;
    });
    await WidgetsBinding.instance.endOfFrame;
    session.firstFrameRendered.removeListener(_checkProbe);
    session.error.removeListener(_checkProbe);
    await session.disposeSession();
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
    final saved = await widget.store.saveCamera(
      id: widget.camera?.id ?? '',
      name: _name.text,
      host: _host.text,
      port: _port.text,
      username: _username.text,
      password: _password.text,
      mainPath: _mainPath.text,
      subPath: _subPath.text,
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
