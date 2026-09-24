import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../app/state/app_store.dart';
import '../../../shared/design_system/page_frame.dart';
import '../../camera_catalog/domain/camera_device.dart';
import '../../camera_catalog/domain/camera_field_validation.dart';
import '../../monitor/application/rtsp_session.dart';
import '../data/local_network_scanner.dart';
import '../domain/rtsp_channel_candidates.dart';

class ChannelFinderPage extends StatefulWidget {
  const ChannelFinderPage({super.key});

  @override
  State<ChannelFinderPage> createState() => _ChannelFinderPageState();
}

class _ChannelFinderPageState extends State<ChannelFinderPage> {
  final _scanner = LocalNetworkScanner();
  final _range = TextEditingController();
  final _host = TextEditingController();
  final _port = TextEditingController(text: '554');
  final _username = TextEditingController(text: 'admin');
  final _password = TextEditingController();
  final _channel = TextEditingController(text: '1');
  final _interfaces = <NetworkInterface>[];
  final _openHosts = <String>[];
  bool _scanning = false;
  bool _finding = false;
  bool _cancel = false;
  int _completed = 0;
  int _total = 0;
  int _candidateIndex = 0;
  List<String> _paths = const [];
  RtspSession? _probe;

  @override
  void initState() {
    super.initState();
    _loadInterfaces();
  }

  @override
  void dispose() {
    _cancel = true;
    unawaited(_probe?.disposeSession());
    _range.dispose();
    _host.dispose();
    _port.dispose();
    _username.dispose();
    _password.dispose();
    _channel.dispose();
    super.dispose();
  }

  Future<void> _loadInterfaces() async {
    try {
      final interfaces = await _scanner.interfaces();
      if (!mounted) return;
      setState(() {
        _interfaces
          ..clear()
          ..addAll(interfaces);
        if (_range.text.isEmpty && interfaces.isNotEmpty) {
          _range.text = _scanner.suggestedRange(interfaces.first) ?? '';
        }
      });
    } on Object {
      if (mounted) {
        _message('Não foi possível consultar as interfaces de rede.');
      }
    }
  }

  Future<void> _scanNetwork() async {
    final port = int.tryParse(_port.text.trim());
    if (port == null || port < 1 || port > 65535) {
      _message('Informe uma porta entre 1 e 65535.');
      return;
    }
    late final List<String> hosts;
    try {
      hosts = _scanner.hostsInRange(_range.text);
    } on FormatException catch (error) {
      _message(error.message);
      return;
    }
    _cancel = false;
    setState(() {
      _scanning = true;
      _openHosts.clear();
      _completed = 0;
      _total = hosts.length;
    });
    try {
      await for (final progress in _scanner.scan(
        hosts,
        port,
        isCancelled: () => _cancel,
      )) {
        if (!mounted) return;
        setState(() {
          _completed = progress.completed;
          _openHosts
            ..clear()
            ..addAll(progress.openHosts);
        });
      }
    } on Object {
      if (mounted) _message('A busca na rede foi interrompida por um erro.');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _findChannels() async {
    final host = _host.text.trim();
    final port = int.tryParse(_port.text.trim());
    if (host.isEmpty || port == null || port < 1 || port > 65535) {
      _message('Informe um endereço de câmera e uma porta válida.');
      return;
    }
    final hostError = CameraFieldValidation.hostError(host);
    if (hostError != null) {
      _message(hostError);
      return;
    }
    final channel = int.tryParse(_channel.text.trim());
    if (channel == null || channel < 1 || channel > 255) {
      _message('Informe um canal entre 1 e 255.');
      return;
    }
    final paths = RtspChannelCandidates.forChannel(channel);
    _cancel = false;
    setState(() {
      _finding = true;
      _paths = paths;
      _candidateIndex = 0;
    });
    String? foundPath;
    for (var index = 0; index < paths.length && !_cancel; index++) {
      if (!mounted) return;
      setState(() => _candidateIndex = index);
      final session = RtspSession(
        camera: CameraDevice(
          id: 'channel-finder',
          name: host,
          host: host,
          port: port,
          username: _username.text.trim(),
          mainPath: paths[index],
        ),
        password: _password.text,
        defaultPort: port,
        bufferMs: 150,
        useMainStream: true,
        firstFrameTimeout: const Duration(seconds: 3),
        retryEnabled: false,
      );
      setState(() => _probe = session);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || _cancel) {
        await session.disposeSession();
        _probe = null;
        break;
      }
      await session.start();
      if (session.firstFrameRendered.value) foundPath = paths[index];
      await session.disposeSession();
      if (mounted) setState(() => _probe = null);
      if (foundPath != null) break;
    }
    if (!mounted) return;
    setState(() => _finding = false);
    if (foundPath != null) {
      setState(() => _paths = [foundPath!]);
      _message('Canal validado: $foundPath');
    } else if (!_cancel) {
      _message('Nenhum dos caminhos testados entregou um quadro de vídeo.');
    }
  }

  Future<void> _saveFoundChannel() async {
    if (_paths.length != 1 || _finding) return;
    final store = AppScope.of(context);
    final saved = await store.saveCamera(
      id: '',
      name: _host.text.trim(),
      host: _host.text.trim(),
      port: _port.text.trim(),
      username: _username.text.trim(),
      password: _password.text,
      mainPath: _paths.single,
      subPath: '',
    );
    if (!mounted) return;
    _message(
      saved
          ? 'Canal salvo no catálogo de câmeras.'
          : store.message ?? 'Não foi possível salvar o canal.',
    );
  }

  void _cancelWork() {
    _cancel = true;
    unawaited(_probe?.disposeSession());
  }

  void _message(String value) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return PageFrame(
      title: 'Achador de canais',
      subtitle:
          'Encontre dispositivos RTSP e valide o caminho que realmente transmite vídeo.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '1. Buscar dispositivos na rede',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'A busca verifica somente se a porta RTSP responde. Ela não altera câmeras nem configurações.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  if (_interfaces.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final interface in _interfaces)
                          ActionChip(
                            avatar: const Icon(Icons.lan_outlined, size: 18),
                            label: Text(
                              '${interface.name} · ${_scanner.suggestedRange(interface) ?? 'IPv4'}',
                            ),
                            onPressed: _scanning
                                ? null
                                : () => setState(
                                    () => _range.text =
                                        _scanner.suggestedRange(interface) ??
                                        '',
                                  ),
                          ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 520;
                      final rangeField = TextField(
                        controller: _range,
                        enabled: !_scanning,
                        decoration: const InputDecoration(
                          labelText: 'Rede IPv4',
                          hintText: '192.168.1.0/24',
                          helperText:
                              'Redes maiores são limitadas automaticamente a /24',
                        ),
                      );
                      final portField = TextField(
                        controller: _port,
                        enabled: !_scanning && !_finding,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Porta RTSP',
                        ),
                      );
                      if (compact) {
                        return Column(
                          children: [
                            rangeField,
                            const SizedBox(height: 10),
                            portField,
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: rangeField),
                          const SizedBox(width: 14),
                          SizedBox(width: 150, child: portField),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: _scanning ? _cancelWork : _scanNetwork,
                        icon: Icon(_scanning ? Icons.stop : Icons.radar),
                        label: Text(
                          _scanning ? 'Cancelar busca' : 'Buscar na rede',
                        ),
                      ),
                      if (_scanning)
                        SizedBox(
                          width: 140,
                          child: LinearProgressIndicator(
                            value: _total == 0 ? null : _completed / _total,
                          ),
                        ),
                      if (_scanning) Text('$_completed / $_total'),
                    ],
                  ),
                  if (_openHosts.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      '${_openHosts.length} dispositivo(s) com porta RTSP aberta',
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final host in _openHosts)
                          ActionChip(
                            label: Text(host),
                            onPressed: () => setState(() => _host.text = host),
                          ),
                      ],
                    ),
                  ] else if (!_scanning && _completed > 0) ...[
                    const SizedBox(height: 12),
                    const Text('Nenhuma porta RTSP encontrada nesta faixa.'),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '2. Identificar o canal com vídeo',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Testa rotas comuns uma por vez e confirma o canal apenas quando o decodificador recebe um quadro real.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _host,
                    enabled: !_finding,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Endereço do dispositivo',
                      hintText: '192.168.1.50',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _channel,
                    enabled: !_finding,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Número do canal no gravador',
                      hintText: '1',
                      helperText:
                          'Usado ao montar caminhos comuns de gravadores',
                    ),
                  ),
                  const SizedBox(height: 10),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 520;
                      final userField = TextField(
                        controller: _username,
                        enabled: !_finding,
                        decoration: const InputDecoration(labelText: 'Usuário'),
                      );
                      final passwordField = TextField(
                        controller: _password,
                        enabled: !_finding,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Senha'),
                      );
                      if (compact) {
                        return Column(
                          children: [
                            userField,
                            const SizedBox(height: 10),
                            passwordField,
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: userField),
                          const SizedBox(width: 12),
                          Expanded(child: passwordField),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: _finding ? _cancelWork : _findChannels,
                        icon: Icon(_finding ? Icons.stop : Icons.manage_search),
                        label: Text(
                          _finding ? 'Cancelar teste' : 'Achar canal',
                        ),
                      ),
                      if (_paths.length == 1 && !_finding)
                        OutlinedButton.icon(
                          onPressed: _saveFoundChannel,
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('Salvar câmera'),
                        ),
                      if (_finding)
                        Text(
                          'Testando rota ${_candidateIndex + 1} de ${_paths.length}…',
                        ),
                      if (_paths.length == 1 && !_finding)
                        Chip(
                          avatar: Icon(
                            Icons.check_circle,
                            color: colorScheme.primary,
                          ),
                          label: Text(_paths.single),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'O usuário e a senha são usados apenas para testar e são gravados no cofre seguro se você salvar a câmera.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          if (_probe?.videoController != null)
            SizedBox(
              width: 1,
              height: 1,
              child: Offstage(
                child: Video(
                  controller: _probe!.videoController!,
                  controls: NoVideoControls,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
