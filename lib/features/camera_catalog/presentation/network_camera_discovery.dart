import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../app/state/app_store.dart';
import '../../discovery/application/stream_quality.dart';
import '../../discovery/application/discovery_cancellation.dart';
import '../../discovery/data/local_network_scanner.dart';
import '../../discovery/data/onvif_discovery_service.dart';
import '../../discovery/domain/rtsp_channel_candidates.dart';
import '../../monitor/application/rtsp_session.dart';
import '../domain/camera_device.dart';
import '../domain/camera_channel.dart';
import 'widgets/discovered_host_group.dart';

class NetworkCameraDiscovery extends StatefulWidget {
  const NetworkCameraDiscovery({super.key});

  @override
  State<NetworkCameraDiscovery> createState() => _NetworkCameraDiscoveryState();
}

class _NetworkCameraDiscoveryState extends State<NetworkCameraDiscovery>
    with WidgetsBindingObserver {
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
  final _channels = <DetectedChannel>[];
  final _selected = <String>{};
  final _onvifHosts = <String>{};
  final _streamChoice = <String, StreamChoice>{};
  bool _expanded = false;
  bool _portEdited = false;
  bool _busy = false;
  bool _cancel = false;
  bool _scanRecorderChannels = false;
  bool _defaultsLoaded = false;
  int _completed = 0;
  int _total = 0;
  String _stage = '';
  RtspSession? _probe;
  DiscoveryCancellation? _cancellation;
  bool _hostAuthenticationFailed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadInterfaces());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      if (_busy) _cancelSearch();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_portEdited) _port.text = '${AppScope.of(context).config.defaultPort}';
    if (_defaultsLoaded) return;
    _defaultsLoaded = true;
    unawaited(_loadDefaults());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancel = true;
    _cancellation?.cancel();
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
    _port.text = '${store.config.defaultPort}';
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
    final port = int.tryParse(_port.text.trim());
    final lastChannel = _scanRecorderChannels
        ? int.tryParse(_lastChannel.text.trim())
        : 1;
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
    final ports = <int>{
      port,
      554,
      8554,
      10554,
      8555,
      ...AppScope.of(
        context,
      ).cameras.map((camera) => camera.effectivePort(port)),
    }.toList();
    setState(() {
      _busy = true;
      _cancel = false;
      _cancellation = DiscoveryCancellation();
      _hosts.clear();
      _portsByHost.clear();
      _hostLabels.clear();
      _onvifHosts.clear();
      _streamChoice.clear();
      _channels.clear();
      _selected.clear();
      _completed = 0;
      _total = hosts.length * ports.length;
      _stage = 'Procurando dispositivos nas portas RTSP comuns';
    });
    try {
      final store = AppScope.of(context);
      _username.text = store.config.defaultUser;
      _password.text = await store.networkDiscoveryPassword() ?? '';
      if (!mounted || _cancel) return;
      await _discoverOnvif();
      final scanHosts = hosts
          .where((host) => !_portsByHost.containsKey(host))
          .toList(growable: false);
      if (mounted) setState(() => _total = scanHosts.length * ports.length);
      var scannedHosts = 0;
      for (final candidatePort in ports) {
        if (_cancel) break;
        final remainingHosts = scanHosts
            .where((host) => !_portsByHost.containsKey(host))
            .toList(growable: false);
        scannedHosts += scanHosts.length - remainingHosts.length;
        await for (final progress in _scanner.scan(
          remainingHosts,
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
        scannedHosts += remainingHosts.length;
        if (mounted && !_cancel) setState(() => _completed = scannedHosts);
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
          _stage = _cancel
              ? 'Busca cancelada. Os resultados encontrados foram mantidos.'
              : '';
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
    final store = AppScope.of(context);
    setState(() => _stage = 'Procurando dispositivos ONVIF');
    final probes = await _onvif.discover(
      _interfaces,
      isCancelled: () => _cancel,
      cancellation: _cancellation,
    );
    for (final probe in probes) {
      if (!mounted || _cancel) return;
      setState(
        () => _stage = 'Lendo canais de ${probe.name ?? probe.sourceAddress}',
      );
      final known = store.cameraForEndpoint(probe.sourceAddress);
      final username = known == null
          ? _username.text.trim()
          : store.resolveCamera(known).username;
      final password = known == null
          ? _password.text
          : await store.passwordFor(known) ?? '';
      if (!mounted || _cancel) return;
      OnvifDevice? device;
      try {
        device = await _onvif.loadProfiles(
          probe,
          username: username,
          password: password,
          isCancelled: () => _cancel,
          cancellation: _cancellation,
        );
      } on OnvifAuthenticationFailure {
        if (!_cancel) {
          _message(
            '${probe.sourceAddress}: ONVIF não aceitou a autenticação. A busca continuará pelas portas RTSP.',
          );
        }
        continue;
      }
      if (device == null) continue;
      final pairs = OnvifStreamPair.group(device.profiles);
      var groupIndex = 0;
      for (final pair in pairs) {
        if (!mounted || _cancel) return;
        groupIndex++;
        final main = pair.main;
        final sub = pair.sub;
        final stream = main.streamUri;
        final host = stream.host;
        final port = stream.hasPort ? stream.port : 554;
        final number = pairs.length == 1
            ? 1
            : int.tryParse(
                    RegExp(r'\d+').firstMatch(pair.sourceKey)?.group(0) ?? '',
                  ) ??
                  groupIndex;
        final mainPath = _rtspPath(stream);
        if (mainPath.isEmpty) continue;
        _onvifHosts.add(host);
        _portsByHost.putIfAbsent(host, () => port);
        final identity = [
          device.manufacturer,
          device.model,
          device.name,
        ].whereType<String>().where((value) => value.trim().isNotEmpty).toSet();
        _hostLabels[host] = identity.isEmpty
            ? host
            : '${identity.join(' · ')} · $host';
        final result = DetectedChannel(
          host: host,
          port: port,
          number: number,
          username: _username.text.trim(),
          password: _password.text,
          mainPath: mainPath,
          mainQuality: main.quality.isEmpty
              ? 'Perfil ONVIF informado'
              : main.quality,
          subPath: sub == null ? null : _rtspPath(sub.streamUri),
          subQuality: sub?.quality,
          verified: false,
          subHost: sub?.streamUri.host,
          subPort: sub == null
              ? null
              : sub.streamUri.hasPort
              ? sub.streamUri.port
              : 554,
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
    final defaultPath = AppScope.of(context).config.defaultPath;
    final targets = _hosts
        .where((host) => !_onvifHosts.contains(host))
        .toList(growable: false);
    setState(() {
      _stage = 'Detectando canais e testando os fluxos';
      _completed = 0;
      _total = targets.length * lastChannel;
    });
    for (final host in targets) {
      _hostAuthenticationFailed = false;
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
        for (final path in {
          if (channel == 1) defaultPath,
          ...RtspChannelCandidates.mainForChannel(channel),
        }) {
          mainQuality = await _probePath(
            host: host,
            port: _portsByHost[host]!,
            username: username,
            password: password,
            path: path,
          );
          if (mainQuality != null || _cancel || _hostAuthenticationFailed) {
            if (mainQuality != null) mainPath = path;
            break;
          }
        }
        if (_cancel) return;
        if (_hostAuthenticationFailed) break;
        if (mainPath == null) continue;
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
        if (subQuality != null &&
            StreamSignature.sameKnownResolution(mainQuality!, subQuality)) {
          subPath = null;
          subQuality = null;
        }
        final result = DetectedChannel(
          host: host,
          port: _portsByHost[host]!,
          number: channel,
          username: username,
          password: password,
          mainPath: mainPath,
          mainQuality: mainQuality!,
          subPath: subPath,
          subQuality: subQuality,
          verified: true,
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
    final store = AppScope.of(context);
    final known = store.cameraForEndpoint(host, port: port, path: path);
    if (known != null) {
      username = store.resolveCamera(known).username;
      password = await store.passwordFor(known) ?? '';
      if (!mounted || _cancel) return null;
    }
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
    session.addListener(_refreshProbe);
    if (mounted) setState(() {});
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || _cancel) {
      session.removeListener(_refreshProbe);
      await session.disposeSession();
      if (identical(_probe, session)) _probe = null;
      return null;
    }
    await session.start();
    final quality = session.firstFrameRendered.value
        ? describeStreamQuality(session)
        : null;
    if (!_cancel && session.authenticationFailed) {
      _hostAuthenticationFailed = true;
      _message(
        '$host: a câmera recusou o usuário ou a senha. Confira a conexão global ou os dados específicos.',
      );
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

  Future<void> _saveSelected() async {
    final store = AppScope.of(context);
    final chosen = _channels
        .where((channel) => _selected.contains(channel.key))
        .toList(growable: false);
    if (chosen.isEmpty) {
      _message('Selecione ao menos um canal para cadastrar.');
      return;
    }
    setState(() => _busy = true);
    final saved = await store.addDiscoveredCameras([
      for (final channel in chosen)
        CameraDevice(
          id: '',
          name: '${channel.host} · Canal ${channel.number}',
          host: channel.host,
          port: channel.port,
          username: '',
          mainPath: _choiceFor(channel) == StreamChoice.sub
              ? channel.subPath!
              : channel.mainPath,
          subPath: _choiceFor(channel) == StreamChoice.both
              ? channel.subPath ?? ''
              : '',
          useGlobalCredentials: true,
          channels: [
            CameraChannel(
              id: channel.mainPath,
              label: 'Canal ${channel.number}',
              main: CameraStream(
                path: _choiceFor(channel) == StreamChoice.sub
                    ? channel.subPath!
                    : channel.mainPath,
                quality: _choiceFor(channel) == StreamChoice.sub
                    ? channel.subQuality ?? ''
                    : channel.mainQuality,
              ),
              sub:
                  _choiceFor(channel) != StreamChoice.both ||
                      channel.subPath == null
                  ? null
                  : CameraStream(
                      path: channel.subPath!,
                      host: channel.subHost == channel.host
                          ? null
                          : channel.subHost,
                      port: channel.subPort == channel.port
                          ? null
                          : channel.subPort,
                      quality: channel.subQuality ?? '',
                    ),
            ),
          ],
        ),
    ]);
    if (!mounted) return;
    setState(() => _busy = false);
    _message('$saved de ${chosen.length} canais adicionados às câmeras.');
  }

  StreamChoice _choiceFor(DetectedChannel channel) {
    if (channel.subPath == null) return StreamChoice.main;
    return _streamChoice[channel.key] ?? StreamChoice.both;
  }

  void _cancelSearch() {
    _cancel = true;
    _cancellation?.cancel();
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

  List<DetectedChannel> _matchingChannels([String? host]) {
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
                          helperText: 'Recomendado /24; máximo /22 (1022 IPs)',
                        ),
                      );
                      final port = TextField(
                        controller: _port,
                        onChanged: (_) => _portEdited = true,
                        enabled: !_busy,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Porta adicional',
                          helperText: 'Busca também portas RTSP comuns',
                        ),
                      );
                      if (compact) {
                        return Column(
                          children: [range, const SizedBox(height: 10), port],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: range),
                          const SizedBox(width: 12),
                          Expanded(child: port),
                        ],
                      );
                    },
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Pesquisar canais de gravadores'),
                    subtitle: const Text(
                      'Sem ONVIF, testa só o canal 1 por IP. Ative para procurar vários canais em DVR/NVR.',
                    ),
                    value: _scanRecorderChannels,
                    onChanged: _busy
                        ? null
                        : (value) =>
                              setState(() => _scanRecorderChannels = value),
                  ),
                  if (_scanRecorderChannels)
                    TextField(
                      controller: _lastChannel,
                      enabled: !_busy,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Procurar até o canal',
                        helperText: 'Entre 1 e 64. Padrão: 16',
                      ),
                    ),
                  const SizedBox(height: 12),
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.settings_ethernet),
                    title: Text('Usa a conexão global'),
                    subtitle: Text(
                      'Usuário, senha e canal vêm dos padrões. Edite-os em Conexão global, fora da busca.',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      FilledButton.icon(
                        onPressed: _busy
                            ? (_cancel ? null : _cancelSearch)
                            : _search,
                        icon: Icon(_busy ? Icons.stop : Icons.search),
                        label: Text(
                          _busy
                              ? (_cancel ? 'Cancelando…' : 'Cancelar pesquisa')
                              : 'Buscar câmeras',
                        ),
                      ),
                      if (_busy)
                        SizedBox(
                          width: 180,
                          child: LinearProgressIndicator(
                            value: _total == 0 ? null : _completed / _total,
                          ),
                        ),
                      if (_stage.isNotEmpty) Text(_stage),
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
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final label = Text(
                          '${_hosts.length} dispositivos · ${visibleChannels.length} canais encontrados',
                          style: Theme.of(context).textTheme.titleMedium,
                        );
                        final selectButton = TextButton(
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
                        );
                        if (constraints.maxWidth < 520) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [label, selectButton],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: label),
                            selectButton,
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    for (final host in _hosts)
                      if (visibleChannels.any(
                        (channel) => channel.host == host,
                      ))
                        DiscoveredHostGroup(
                          host: host,
                          displayName: _hostLabels[host] ?? host,
                          channels: visibleChannels
                              .where((channel) => channel.host == host)
                              .toList(growable: false),
                          selected: _selected,
                          choiceFor: _choiceFor,
                          onChoice: (item, choice) =>
                              setState(() => _streamChoice[item.key] = choice),
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
