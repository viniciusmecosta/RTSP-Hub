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
  final _lastChannel = TextEditingController(text: '16');
  final _interfaces = <NetworkInterface>[];
  final _openHosts = <String>[];
  bool _scanning = false;
  bool _finding = false;
  bool _cancel = false;
  int _completed = 0;
  int _total = 0;
  int _activeChannel = 1;
  String? _selectedCameraId;
  bool _cameraListInitialized = false;
  List<_FoundChannel> _results = const [];
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
    _lastChannel.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_cameraListInitialized) return;
    _cameraListInitialized = true;
    final cameras = AppScope.of(context).cameras;
    if (cameras.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _selectCamera(cameras.first.id);
      });
    }
  }

  Future<void> _selectCamera(String? id) async {
    if (id == null) return;
    final store = AppScope.of(context);
    final camera = store.cameras.where((item) => item.id == id).firstOrNull;
    if (camera == null) return;
    setState(() {
      _selectedCameraId = id;
      _host.text = camera.host;
      _port.text = camera.effectivePort(store.config.defaultPort).toString();
      _username.text = camera.username;
      _password.clear();
      _results = const [];
    });
    final secret = await store.passwordFor(camera);
    if (mounted && _selectedCameraId == id) _password.text = secret ?? '';
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
    final store = AppScope.of(context);
    final selectedCamera = store.cameras
        .where((camera) => camera.id == _selectedCameraId)
        .firstOrNull;
    final lastChannel = int.tryParse(_lastChannel.text.trim());
    if (lastChannel == null || lastChannel < 1 || lastChannel > 64) {
      _message('Escolha um limite de canal entre 1 e 64.');
      return;
    }
    final reachable = await _scanner.isRtspPortOpen(
      host,
      port,
      timeout: const Duration(milliseconds: 700),
    );
    if (!mounted) return;
    if (!reachable) {
      _message(
        'A porta RTSP não respondeu. Confira o endereço, a porta e a rede.',
      );
      return;
    }
    _cancel = false;
    setState(() {
      _finding = true;
      _results = const [];
    });
    for (var channel = 1; channel <= lastChannel && !_cancel; channel++) {
      if (!mounted) return;
      setState(() {
        _activeChannel = channel;
      });
      String? mainPath;
      String mainQuality = '';
      for (final path in RtspChannelCandidates.mainForChannel(
        channel,
        preferredPath: channel == 1 ? selectedCamera?.mainPath : null,
      )) {
        final quality = await _probePath(host: host, port: port, path: path);
        if (quality != null) {
          mainPath = path;
          mainQuality = quality;
          break;
        }
        if (_cancel || !mounted) break;
      }
      if (mainPath == null || _cancel || !mounted) continue;
      String? subPath;
      String? subQuality;
      for (final path in RtspChannelCandidates.subForChannel(
        channel,
        preferredPath: channel == 1 ? selectedCamera?.subPath : null,
      )) {
        final quality = await _probePath(host: host, port: port, path: path);
        if (quality != null) {
          subPath = path;
          subQuality = quality;
          break;
        }
        if (_cancel || !mounted) break;
      }
      if (!_cancel && mounted) {
        setState(() {
          _results = [
            ..._results,
            _FoundChannel(
              number: channel,
              mainPath: mainPath!,
              mainQuality: mainQuality,
              subPath: subPath,
              subQuality: subQuality,
            ),
          ];
        });
      }
    }
    if (!mounted) return;
    setState(() => _finding = false);
    if (!_cancel && _results.isEmpty) {
      _message('Nenhum canal com vídeo foi encontrado até o número informado.');
    } else if (!_cancel) {
      _message('${_results.length} canal(is) com vídeo encontrados.');
    }
  }

  Future<String?> _probePath({
    required String host,
    required int port,
    required String path,
  }) async {
    final session = RtspSession(
      camera: CameraDevice(
        id: 'channel-finder',
        name: host,
        host: host,
        port: port,
        username: _username.text.trim(),
        mainPath: path,
      ),
      password: _password.text,
      defaultPort: port,
      bufferMs: 120,
      useMainStream: true,
      firstFrameTimeout: const Duration(milliseconds: 1800),
      retryEnabled: false,
    );
    setState(() => _probe = session);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || _cancel) {
      await session.disposeSession();
      _probe = null;
      return null;
    }
    await session.start();
    final found = session.firstFrameRendered.value;
    final quality = found ? _videoQuality(session) : null;
    await session.disposeSession();
    if (mounted) setState(() => _probe = null);
    return quality;
  }

  String _videoQuality(RtspSession session) {
    final player = session.player;
    if (player == null) return 'Qualidade indisponível';
    final track = player.state.tracks.video.firstWhere(
      (item) => item.id != 'auto' && item.id != 'no',
      orElse: () => player.state.track.video,
    );
    final width = track.w ?? player.state.videoParams.w;
    final height = track.h ?? player.state.videoParams.h;
    final codec = track.codec;
    final fps = track.fps;
    final details = <String>[
      if (width != null && height != null) '$width×$height',
      if (fps != null && fps > 0) '${fps.toStringAsFixed(1)} fps',
      if (codec != null && codec.isNotEmpty) codec.toUpperCase(),
      if (track.bitrate case final int bitrate when bitrate > 0)
        '${(bitrate / 1000000).toStringAsFixed(1)} Mbps',
    ];
    return details.isEmpty ? 'Vídeo detectado' : details.join(' · ');
  }

  Future<void> _saveFoundChannel(_FoundChannel result) async {
    if (_finding) return;
    final store = AppScope.of(context);
    final original = store.cameras
        .where((camera) => camera.id == _selectedCameraId)
        .firstOrNull;
    final updateOriginal =
        original?.host == _host.text.trim() &&
        original?.effectivePort(store.config.defaultPort) ==
            int.tryParse(_port.text.trim()) &&
        original?.mainPath == result.mainPath;
    final saved = await store.saveCamera(
      id: updateOriginal ? original!.id : '',
      name: updateOriginal
          ? original!.name
          : '${_host.text.trim()} · Canal ${result.number}',
      host: _host.text.trim(),
      port: _port.text.trim(),
      username: _username.text.trim(),
      password: _password.text,
      mainPath: result.mainPath,
      subPath: result.subPath ?? '',
    );
    if (!mounted) return;
    _message(
      saved
          ? 'Canal ${result.number} salvo no catálogo de câmeras.'
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
                    'Opcional · localizar endereços na rede',
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
                        onPressed: _scanning
                            ? _cancelWork
                            : _finding
                            ? null
                            : _scanNetwork,
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
                    '1. Escolher canais da câmera',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Selecione uma câmera cadastrada. O achador testa cada canal em sequência, mede o vídeo e oferece os fluxos principal e secundário para você escolher.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 14),
                  if (AppScope.of(context).cameras.isNotEmpty) ...[
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCameraId,
                      decoration: const InputDecoration(
                        labelText: 'Câmera cadastrada',
                        prefixIcon: Icon(Icons.videocam_outlined),
                      ),
                      items: [
                        for (final camera in AppScope.of(context).cameras)
                          DropdownMenuItem(
                            value: camera.id,
                            child: Text(
                              '${camera.name} · ${camera.host}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: _finding ? null : _selectCamera,
                    ),
                    const SizedBox(height: 10),
                  ],
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
                    controller: _lastChannel,
                    enabled: !_finding,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Buscar canais do 1 até',
                      hintText: '16',
                      helperText:
                          'Limite de 64; apenas um fluxo é testado por vez.',
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
                        onPressed: _finding
                            ? _cancelWork
                            : _scanning
                            ? null
                            : _findChannels,
                        icon: Icon(_finding ? Icons.stop : Icons.manage_search),
                        label: Text(
                          _finding ? 'Cancelar teste' : 'Achar canal',
                        ),
                      ),
                      if (_finding) ...[
                        SizedBox(
                          width: 140,
                          child: LinearProgressIndicator(
                            value:
                                _activeChannel /
                                (int.tryParse(_lastChannel.text) ?? 16),
                          ),
                        ),
                        Text('Canal $_activeChannel de ${_lastChannel.text}'),
                      ],
                    ],
                  ),
                  if (_results.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    for (final result in _results)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    color: colorScheme.primary,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Canal ${result.number}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: _finding
                                        ? null
                                        : () => _saveFoundChannel(result),
                                    icon: const Icon(Icons.add),
                                    label: const Text('Adicionar'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text('Principal · ${result.mainQuality}'),
                              Text(
                                result.subPath == null
                                    ? 'Fluxo secundário não detectado'
                                    : 'Secundário · ${result.subQuality}',
                              ),
                              const SizedBox(height: 4),
                              Text(
                                result.mainPath,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              if (result.subPath case final String subPath)
                                Text(
                                  subPath,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
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
