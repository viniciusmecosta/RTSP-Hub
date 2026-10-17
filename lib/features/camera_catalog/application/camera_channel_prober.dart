import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../discovery/application/stream_quality.dart';
import '../../discovery/application/discovery_cancellation.dart';
import '../../discovery/data/onvif_discovery_service.dart';
import '../../discovery/domain/rtsp_channel_candidates.dart';
import '../../monitor/application/rtsp_session.dart';
import '../domain/camera_device.dart';
import '../domain/found_channel.dart';

typedef ChannelQualityProbe =
    Future<String?> Function({
      required String host,
      required int port,
      required String username,
      required String password,
      required String path,
      required bool Function() isCancelled,
    });

class CameraChannelProber {
  CameraChannelProber({OnvifDiscoveryService? onvif, this.qualityProbe})
    : _onvif = onvif ?? OnvifDiscoveryService();

  final OnvifDiscoveryService _onvif;
  final ChannelQualityProbe? qualityProbe;
  RtspSession? _activeProbe;
  DiscoveryCancellation? _cancellation;
  String? lastFailure;
  bool _authenticationFailed = false;

  void cancel() {
    _cancellation?.cancel();
    final probe = _activeProbe;
    if (probe != null) unawaited(probe.disposeSession());
  }

  RtspSession? get activeProbe => _activeProbe;

  Future<void> dispose() async {
    cancel();
    final probe = _activeProbe;
    _activeProbe = null;
    if (probe != null) {
      await probe.disposeSession();
    }
  }

  Future<List<FoundChannel>> findChannels({
    required String host,
    required int port,
    required String username,
    required String password,
    required String defaultPath,
    required bool searchRecorderChannels,
    required bool Function() isCancelled,
    required void Function(String stage) onProgress,
  }) async {
    final token = DiscoveryCancellation();
    _cancellation = token;
    lastFailure = null;
    _authenticationFailed = false;
    final externalCancelled = isCancelled;
    isCancelled = () => token.isCancelled || externalCancelled();
    final found = <FoundChannel>[];
    onProgress('Consultando ONVIF em $host');
    try {
      final device = await _onvif.loadProfiles(
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
        isCancelled: isCancelled,
        cancellation: token,
      );
      for (final pair in OnvifStreamPair.group(device?.profiles ?? const [])) {
        final mainUri = pair.main.streamUri;
        final subUri = pair.sub?.streamUri;
        if (mainUri.host.isEmpty ||
            (mainUri.hasPort && (mainUri.port < 1 || mainUri.port > 65535))) {
          continue;
        }
        String path(Uri uri) => uri.hasQuery
            ? '${uri.path}?${uri.query}'
            : (uri.path.isEmpty ? '/' : uri.path);
        found.add(
          FoundChannel(
            number:
                int.tryParse(
                  RegExp(r'\d+').firstMatch(pair.sourceKey)?.group(0) ?? '',
                ) ??
                found.length + 1,
            host: mainUri.host,
            port: mainUri.hasPort ? mainUri.port : 554,
            subHost: subUri?.host,
            subPort: subUri == null
                ? null
                : subUri.hasPort
                ? subUri.port
                : 554,
            mainPath: path(pair.main.streamUri),
            mainQuality: pair.main.quality,
            subPath: pair.sub == null ? null : path(pair.sub!.streamUri),
            subQuality: pair.sub?.quality,
          ),
        );
      }
      if (found.isEmpty && !isCancelled()) {
        await _probeCandidates(
          host: host,
          port: port,
          username: username,
          password: password,
          defaultPath: defaultPath,
          searchRecorderChannels: searchRecorderChannels,
          isCancelled: isCancelled,
          onProgress: onProgress,
          found: found,
        );
      }
    } on OnvifAuthenticationFailure {
      lastFailure =
          'A câmera recusou as credenciais ONVIF. Confira o usuário e a senha específicos ou globais.';
    } on Object {
      lastFailure =
          'Não foi possível consultar os canais. Confira o endereço, a porta e a conexão.';
    }
    return found;
  }

  Future<void> _probeCandidates({
    required String host,
    required int port,
    required String username,
    required String password,
    required String defaultPath,
    required bool searchRecorderChannels,
    required bool Function() isCancelled,
    required void Function(String stage) onProgress,
    required List<FoundChannel> found,
  }) async {
    final lastChannel = searchRecorderChannels ? 16 : 1;
    for (var channel = 1; channel <= lastChannel; channel++) {
      if (isCancelled() || _authenticationFailed) return;
      onProgress('Testando canal $channel em $host');
      String? mainPath;
      String? mainQuality;
      for (final path in {
        if (channel == 1) defaultPath,
        ...RtspChannelCandidates.mainForChannel(channel),
      }) {
        mainQuality = await probeQuality(
          host: host,
          port: port,
          username: username,
          password: password,
          path: path,
          isCancelled: isCancelled,
        );
        if (isCancelled() || _authenticationFailed) return;
        if (mainQuality != null) {
          mainPath = path;
          break;
        }
      }
      if (mainPath == null) continue;
      String? subPath;
      String? subQuality;
      for (final path in RtspChannelCandidates.subForChannel(channel)) {
        subQuality = await probeQuality(
          host: host,
          port: port,
          username: username,
          password: password,
          path: path,
          isCancelled: isCancelled,
        );
        if (isCancelled() || _authenticationFailed) return;
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
        FoundChannel(
          number: channel,
          host: host,
          port: port,
          mainPath: mainPath,
          mainQuality: mainQuality!,
          subPath: subPath,
          subQuality: subQuality,
        ),
      );
    }
  }

  Future<String?> probeQuality({
    required String host,
    required int port,
    required String username,
    required String password,
    required String path,
    required bool Function() isCancelled,
    void Function()? onSessionUpdate,
  }) async {
    if (qualityProbe != null) {
      return qualityProbe!(
        host: host,
        port: port,
        username: username,
        password: password,
        path: path,
        isCancelled: isCancelled,
      );
    }
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
    _activeProbe = session;
    if (onSessionUpdate != null) session.addListener(onSessionUpdate);
    await WidgetsBinding.instance.endOfFrame;
    String? quality;
    if (!isCancelled()) {
      await session.start();
      if (session.firstFrameRendered.value) {
        quality = describeStreamQuality(session);
      } else if (!isCancelled()) {
        lastFailure = session.error.value;
        _authenticationFailed = session.authenticationFailed;
      }
    }
    if (onSessionUpdate != null) session.removeListener(onSessionUpdate);
    await session.disposeSession();
    if (identical(_activeProbe, session)) {
      _activeProbe = null;
    }
    return quality;
  }
}
