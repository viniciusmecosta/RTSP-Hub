import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../app/state/app_store.dart';
import '../../discovery/data/local_network_scanner.dart';
import '../../discovery/data/onvif_discovery_service.dart';
import '../../discovery/domain/rtsp_channel_candidates.dart';
import '../../monitor/application/rtsp_session.dart';
import '../domain/camera_device.dart';

class NetworkCameraDiscovery extends StatefulWidget {
  const NetworkCameraDiscovery({super.key});

  @override
  State<NetworkCameraDiscovery> createState() => _NetworkCameraDiscoveryState();
}

class _NetworkCameraDiscoveryState extends State<NetworkCameraDiscovery> {
  final _scanner = LocalNetworkScanner();
  final _onvif = OnvifDiscoveryService();
  final _range = TextEditingController();
  final _port = TextEditingController(text: '554');
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _lastChannel = TextEditingController(text: '16');
  final _resultFilter = TextEditingController();
  final _interfaces = <NetworkInterface>[];
  final _hosts = <String>[];
  final _portsByHost = <String, int>{};
  final _hostLabels = <String, String>{};
  final _channels = <_DetectedChannel>[];
  final _selected = <String>{};
  bool _expanded = false;
  bool _busy = false;
  bool _cancel = false;
  bool _obscurePassword = true;
  bool _defaultsLoaded = false;
  int _completed = 0;
  int _total = 0;
  String _stage = '';
  RtspSession? _probe;

  @override
  void initState() {
    super.initState();
    unawaited(_loadInterfaces());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_defaultsLoaded) return;
    _defaultsLoaded = true;
    unawaited(_loadDefaults());
  }

  @override
  void dispose() {
    _cancel = true;
    unawaited(_probe?.disposeSession());
    _range.dispose();
    _port.dispose();
    _username.dispose();
    _password.dispose();
    _lastChannel.dispose();
    _resultFilter.dispose();
    super.dispose();
  }

  Future<void> _loadDefaults() async {
    final store = AppScope.of(context);
    _username.text = store.config.defaultUser;
    final password = await store.networkDiscoveryPassword();
    if (mounted && password != null) _password.text = password;
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
        _message('Não foi possível consultar a rede deste dispositivo.');
      }
    }
  }

  Future<void> _search() async {
    final store = AppScope.of(context);
    final port = int.tryParse(_port.text.trim());
    final lastChannel = int.tryParse(_lastChannel.text.trim());
    final user = _username.text.trim();
    if (port == null || port < 1 || port > 65535) {
      _message('Informe uma porta RTSP entre 1 e 65535.');
      return;
    }
    if (lastChannel == null || lastChannel < 1 || lastChannel > 64) {
      _message('Informe o último canal entre 1 e 64.');
      return;
    }
    if (user.length > 128 || _password.text.length > 1024) {
      _message('Confira o tamanho do usuário e da senha global.');
      return;
    }
    late final List<String> hosts;
    try {
      hosts = _scanner.hostsInRange(_range.text);
    } on FormatException catch (error) {
      _message(error.message);
      return;
    }
    final ports = <int>{port, 554, 8554, 10554, 8555}.toList();
    setState(() {
      _busy = true;
      _cancel = false;
      _hosts.clear();
      _portsByHost.clear();
      _hostLabels.clear();
      _channels.clear();
      _selected.clear();
      _completed = 0;
      _total = hosts.length * ports.length;
      _stage = 'Procurando dispositivos nas portas RTSP comuns';
    });
    final saved = await store.saveNetworkDiscoveryCredentials(
      username: user,
      password: _password.text,
    );
    if (!saved) {
      if (mounted) {
        setState(() => _busy = false);
        _message(
          store.message ?? 'Não foi possível salvar as credenciais globais.',
        );
      }
      return;
    }
    try {
      await _discoverOnvif();
      var scannedHosts = 0;
      for (final candidatePort in ports) {
        if (_cancel) break;
        await for (final progress in _scanner.scan(
          hosts,
          candidatePort,
          isCancelled: () => _cancel,
        )) {
          if (!mounted || _cancel) break;
          setState(() {
            _completed = scannedHosts + progress.completed;
            for (final host in progress.openHosts) {
              _portsByHost.putIfAbsent(host, () => candidatePort);
              _hostLabels.putIfAbsent(host, () => host);
            }
            _hosts
              ..clear()
              ..addAll(_portsByHost.keys);
          });
        }
        scannedHosts += hosts.length;
      }
      if (!_cancel && mounted && _hosts.isNotEmpty) {
        await _inspectHosts(lastChannel: lastChannel);
      }
    } on Object {
      if (mounted) {
        _message('A pesquisa foi interrompida por um erro inesperado.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _probe = null;
          _stage = '';
        });
      }
    }
    if (mounted && !_cancel && _hosts.isEmpty) {
      _message('Nenhum dispositivo respondeu nas portas RTSP verificadas.');
    } else if (mounted && !_cancel && _channels.isEmpty) {
      _message(
        'Os dispositivos responderam, mas nenhum caminho de vídeo conhecido abriu.',
      );
    }
  }

  Future<void> _discoverOnvif() async {
    if (_interfaces.isEmpty) return;
    setState(() => _stage = 'Procurando dispositivos ONVIF');
    final probes = await _onvif.discover(
      _interfaces,
      isCancelled: () => _cancel,
    );
    for (final probe in probes) {
      if (!mounted || _cancel) return;
      setState(
        () => _stage = 'Lendo canais de ${probe.name ?? probe.sourceAddress}',
      );
      final device = await _onvif.loadProfiles(
        probe,
        username: _username.text.trim(),
        password: _password.text,
        isCancelled: () => _cancel,
      );
      if (device == null) continue;
      final groups = <String, List<OnvifProfile>>{};
      for (final profile in device.profiles) {
        final source = profile.sourceToken?.trim();
        final group = source == null || source.isEmpty ? profile.name : source;
        groups.putIfAbsent(group, () => []).add(profile);
      }
      var groupIndex = 0;
      for (final entry in groups.entries) {
        if (!mounted || _cancel) return;
        groupIndex++;
        final profiles = [...entry.value]
          ..sort((left, right) => right.pixelCount.compareTo(left.pixelCount));
        final main = profiles.first;
        final sub = profiles.length > 1 ? profiles.last : null;
        final stream = main.streamUri;
        final host = stream.host;
        final port = stream.hasPort ? stream.port : 554;
        final number =
            int.tryParse(
              RegExp(r'\d+').firstMatch(entry.key)?.group(0) ?? '',
            ) ??
            groupIndex;
        final mainPath = _rtspPath(stream);
        if (mainPath.isEmpty) continue;
        _portsByHost.putIfAbsent(host, () => port);
        final identity = [
          device.manufacturer,
          device.model,
          device.name,
        ].whereType<String>().where((value) => value.trim().isNotEmpty).toSet();
        _hostLabels[host] = identity.isEmpty
            ? host
            : '${identity.join(' · ')} · $host';
        final result = _DetectedChannel(
          host: host,
          port: port,
          number: number,
          username: _username.text.trim(),
          password: _password.text,
          mainPath: mainPath,
          mainQuality: main.quality.isEmpty
              ? 'Vídeo ONVIF detectado'
              : main.quality,
          subPath: sub == null ? null : _rtspPath(sub.streamUri),
          subQuality: sub?.quality,
        );
        if (_channels.any((item) => item.key == result.key)) continue;
        setState(() {
          _channels.add(result);
          _selected.add(result.key);
          _hosts
            ..clear()
            ..addAll(_portsByHost.keys);
        });
      }
    }
  }

  String _rtspPath(Uri uri) {
    final path = uri.path.isEmpty ? '/' : uri.path;
    return uri.hasQuery ? '$path?${uri.query}' : path;
  }

  Future<void> _inspectHosts({required int lastChannel}) async {
    final username = _username.text.trim();
    final password = _password.text;
    setState(() {
      _stage = 'Detectando canais e testando os fluxos';
      _completed = 0;
      _total = _hosts.length * lastChannel;
    });
    for (final host in List<String>.of(_hosts)) {
      for (var channel = 1; channel <= lastChannel; channel++) {
        if (!mounted || _cancel) return;
        if (_channels.any(
          (item) => item.host == host && item.number == channel,
        )) {
          continue;
        }
        setState(() {
          _completed++;
          _stage = 'Testando $host · canal $channel de $lastChannel';
        });
        String? mainPath;
        String? mainQuality;
        for (final path in RtspChannelCandidates.mainForChannel(channel)) {
          mainQuality = await _probePath(
            host: host,
            port: _portsByHost[host]!,
            username: username,
            password: password,
            path: path,
          );
          if (mainQuality != null || _cancel) {
            if (mainQuality != null) mainPath = path;
            break;
          }
        }
        if (mainPath == null || _cancel) continue;
        String? subPath;
        String? subQuality;
        for (final path in RtspChannelCandidates.subForChannel(channel)) {
          subQuality = await _probePath(
            host: host,
            port: _portsByHost[host]!,
            username: username,
            password: password,
            path: path,
          );
          if (subQuality != null || _cancel) {
            if (subQuality != null) subPath = path;
            break;
          }
        }
        if (!mounted || _cancel) return;
        final result = _DetectedChannel(
          host: host,
          port: _portsByHost[host]!,
          number: channel,
          username: username,
          password: password,
          mainPath: mainPath,
          mainQuality: mainQuality!,
          subPath: subPath,
          subQuality: subQuality,
        );
        setState(() {
          _channels.add(result);
          _selected.add(result.key);
        });
      }
    }
  }

  Future<String?> _probePath({
    required String host,
    required int port,
    required String username,
    required String password,
    required String path,
  }) async {
    final session = RtspSession(
      camera: CameraDevice(
        id: 'network-search',
        name: host,
        host: host,
        port: port,
        username: username,
        mainPath: path,
      ),
      password: password,
      defaultPort: port,
      bufferMs: 120,
      useMainStream: true,
      firstFrameTimeout: const Duration(milliseconds: 1350),
      retryEnabled: false,
    );
    _probe = session;
    if (mounted) setState(() {});
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || _cancel) {
      await session.disposeSession();
      if (identical(_probe, session)) _probe = null;
      return null;
    }
    await session.start();
    final quality = session.firstFrameRendered.value
        ? _videoQuality(session)
        : null;
    await session.disposeSession();
    if (identical(_probe, session)) {
      _probe = null;
      if (mounted) setState(() {});
    }
    return quality;
  }

  String _videoQuality(RtspSession session) {
    final player = session.player;
    if (player == null) return 'Vídeo detectado';
    final track = player.state.tracks.video.firstWhere(
      (item) => item.id != 'auto' && item.id != 'no',
      orElse: () => player.state.track.video,
    );
    final width = track.w ?? player.state.videoParams.w;
    final height = track.h ?? player.state.videoParams.h;
    final details = <String>[
      if (width != null && height != null) '$width×$height',
      if (track.fps case final fps? when fps > 0)
        '${fps.toStringAsFixed(1)} fps',
      if (track.codec case final codec? when codec.isNotEmpty)
        codec.toUpperCase(),
      if (track.bitrate case final int bitrate when bitrate > 0)
        '${(bitrate / 1000000).toStringAsFixed(1)} Mbps',
    ];
    return details.isEmpty ? 'Vídeo detectado' : details.join(' · ');
  }

  Future<void> _saveSelected() async {
    final store = AppScope.of(context);
    final chosen = _channels.where(
      (channel) => _selected.contains(channel.key),
    );
    if (chosen.isEmpty) {
      _message('Selecione ao menos um canal para cadastrar.');
      return;
    }
    setState(() => _busy = true);
    var saved = 0;
    for (final channel in chosen) {
      final ok = await store.saveCamera(
        id: '',
        name: '${channel.host} · Canal ${channel.number}',
        host: channel.host,
        port: channel.port.toString(),
        username: channel.username,
        password: channel.password,
        mainPath: channel.mainPath,
        subPath: channel.subPath ?? '',
        useGlobalCredentials: true,
      );
      if (ok) saved++;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    _message('$saved de ${_selected.length} canais adicionados às câmeras.');
  }

  void _cancelSearch() {
    _cancel = true;
    unawaited(_probe?.disposeSession());
    setState(() {
      _stage = 'Cancelando pesquisa';
    });
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  List<_DetectedChannel> _matchingChannels([String? host]) {
    final query = _resultFilter.text.trim().toLowerCase();
    return _channels
        .where((channel) {
          if (host != null && channel.host != host) return false;
          if (query.isEmpty) return true;
          final searchable = [
            _hostLabels[channel.host] ?? channel.host,
            '${channel.number}',
            channel.mainPath,
            channel.subPath ?? '',
            channel.mainQuality,
            channel.subQuality ?? '',
          ].join(' ').toLowerCase();
          return searchable.contains(query);
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final visibleChannels = _matchingChannels();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: colors.primaryContainer,
              foregroundColor: colors.primary,
              child: const Icon(Icons.travel_explore_outlined),
            ),
            title: const Text('Encontrar câmeras na rede'),
            subtitle: const Text(
              'Detecte dispositivos RTSP, canais e caminhos de vídeo para cadastrar em lote.',
            ),
            trailing: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
            onTap: _busy ? null : () => setState(() => _expanded = !_expanded),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                            onPressed: _busy
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
                      final compact = constraints.maxWidth < 620;
                      final range = TextField(
                        controller: _range,
                        enabled: !_busy,
                        decoration: const InputDecoration(
                          labelText: 'Rede IPv4',
                          hintText: '192.168.1.0/24',
                          helperText: 'Exemplo: 192.168.1.0/24',
                        ),
                      );
                      final port = TextField(
                        controller: _port,
                        enabled: !_busy,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Porta adicional',
                          helperText: 'Busca também portas RTSP comuns',
                        ),
                      );
                      final channels = TextField(
                        controller: _lastChannel,
                        enabled: !_busy,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Procurar até o canal',
                          helperText: 'Padrão: 16',
                        ),
                      );
                      if (compact) {
                        return Column(
                          children: [
                            range,
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(child: port),
                                const SizedBox(width: 10),
                                Expanded(child: channels),
                              ],
                            ),
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: range),
                          const SizedBox(width: 12),
                          Expanded(child: port),
                          const SizedBox(width: 12),
                          Expanded(child: channels),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 520;
                      final username = TextField(
                        controller: _username,
                        enabled: !_busy,
                        maxLength: 128,
                        decoration: const InputDecoration(
                          labelText: 'Usuário global',
                          helperText:
                              'Usado para testar as câmeras encontradas',
                        ),
                      );
                      final password = TextField(
                        controller: _password,
                        enabled: !_busy,
                        obscureText: _obscurePassword,
                        maxLength: 1024,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: InputDecoration(
                          labelText: 'Senha global',
                          helperText:
                              'Guardada no cofre seguro deste dispositivo',
                          suffixIcon: IconButton(
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                      );
                      if (compact) {
                        return Column(
                          children: [
                            username,
                            const SizedBox(height: 10),
                            password,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: username),
                          const SizedBox(width: 12),
                          Expanded(child: password),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      FilledButton.icon(
                        onPressed: _busy ? _cancelSearch : _search,
                        icon: Icon(_busy ? Icons.stop : Icons.search),
                        label: Text(
                          _busy ? 'Cancelar pesquisa' : 'Buscar câmeras',
                        ),
                      ),
                      if (_busy)
                        SizedBox(
                          width: 180,
                          child: LinearProgressIndicator(
                            value: _total == 0 ? null : _completed / _total,
                          ),
                        ),
                      if (_busy) Text(_stage),
                    ],
                  ),
                  if (_channels.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    TextField(
                      controller: _resultFilter,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText:
                            'Filtrar por fabricante, modelo, câmera ou canal',
                        prefixIcon: Icon(Icons.filter_alt_outlined),
                        hintText: 'Ex.: Hikvision, Portaria ou 3',
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${_hosts.length} dispositivos · ${visibleChannels.length} canais encontrados',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() {
                                  final allVisibleSelected = visibleChannels
                                      .every(
                                        (channel) =>
                                            _selected.contains(channel.key),
                                      );
                                  if (allVisibleSelected) {
                                    _selected.removeAll(
                                      visibleChannels.map(
                                        (channel) => channel.key,
                                      ),
                                    );
                                  } else {
                                    _selected.addAll(
                                      visibleChannels.map(
                                        (channel) => channel.key,
                                      ),
                                    );
                                  }
                                }),
                          child: Text(
                            visibleChannels.isNotEmpty &&
                                    visibleChannels.every(
                                      (channel) =>
                                          _selected.contains(channel.key),
                                    )
                                ? 'Desmarcar filtrados'
                                : 'Selecionar filtrados',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    for (final host in _hosts)
                      if (visibleChannels.any(
                        (channel) => channel.host == host,
                      ))
                        _DiscoveredHostGroup(
                          host: host,
                          displayName: _hostLabels[host] ?? host,
                          channels: visibleChannels
                              .where((channel) => channel.host == host)
                              .toList(growable: false),
                          selected: _selected,
                          onChanged: (item, value) => setState(() {
                            if (value) {
                              _selected.add(item.key);
                            } else {
                              _selected.remove(item.key);
                            }
                          }),
                        ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: _busy ? null : _saveSelected,
                        icon: const Icon(Icons.add_to_photos_outlined),
                        label: Text(
                          'Cadastrar ${_selected.length} selecionados',
                        ),
                      ),
                    ),
                  ] else if (!_busy && _hosts.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      '${_hosts.length} dispositivos responderam à porta RTSP. Nenhum canal de vídeo foi confirmado.',
                    ),
                  ],
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
                  const SizedBox(height: 8),
                  Text(
                    'A busca testa um fluxo por vez para reduzir o uso de CPU. Câmeras em outra porta, VLAN ou faixa de rede não aparecerão nesta busca.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DiscoveredHostGroup extends StatelessWidget {
  const _DiscoveredHostGroup({
    required this.host,
    required this.displayName,
    required this.channels,
    required this.selected,
    required this.onChanged,
  });

  final String host;
  final String displayName;
  final List<_DetectedChannel> channels;
  final Set<String> selected;
  final void Function(_DetectedChannel channel, bool selected) onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                displayName,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            for (final channel in channels)
              CheckboxListTile(
                value: selected.contains(channel.key),
                onChanged: (value) => onChanged(channel, value ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                title: Text('Canal ${channel.number} · ${channel.mainQuality}'),
                subtitle: Text(
                  'Principal: ${channel.mainPath}${channel.subPath == null ? '' : '\nSecundário: ${channel.subPath} · ${channel.subQuality}'}',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DetectedChannel {
  const _DetectedChannel({
    required this.host,
    required this.port,
    required this.number,
    required this.username,
    required this.password,
    required this.mainPath,
    required this.mainQuality,
    required this.subPath,
    required this.subQuality,
  });

  final String host;
  final int port;
  final int number;
  final String username;
  final String password;
  final String mainPath;
  final String mainQuality;
  final String? subPath;
  final String? subQuality;
  String get key => '$host:$port:$number';
}
