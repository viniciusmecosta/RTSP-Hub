import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:xml/xml.dart';

class OnvifDiscoveryService {
  static final _multicastAddress = InternetAddress('239.255.255.250');
  static const _deviceAction =
      'http://www.onvif.org/ver10/device/wsdl/GetCapabilities';
  static const _deviceInformationAction =
      'http://www.onvif.org/ver10/device/wsdl/GetDeviceInformation';
  static const _mediaProfilesAction =
      'http://www.onvif.org/ver10/media/wsdl/GetProfiles';
  static const _streamUriAction =
      'http://www.onvif.org/ver10/media/wsdl/GetStreamUri';

  Future<List<OnvifProbeDevice>> discover(
    List<NetworkInterface> interfaces, {
    Duration listenDuration = const Duration(milliseconds: 1800),
    bool Function()? isCancelled,
  }) async {
    final devices = <String, OnvifProbeDevice>{};
    for (final interface in interfaces) {
      if (isCancelled?.call() ?? false) break;
      for (final address in interface.addresses.where(
        (item) => item.type == InternetAddressType.IPv4 && !item.isLoopback,
      )) {
        if (isCancelled?.call() ?? false) break;
        RawDatagramSocket? socket;
        StreamSubscription<RawSocketEvent>? subscription;
        try {
          socket = await RawDatagramSocket.bind(address, 0);
          socket.multicastHops = 1;
          socket.broadcastEnabled = true;
          socket.joinMulticast(_multicastAddress, interface);
          subscription = socket.listen((event) {
            if (event != RawSocketEvent.read) return;
            final datagram = socket?.receive();
            if (datagram == null) return;
            final parsed = parseProbeResponse(
              utf8.decode(datagram.data, allowMalformed: true),
              sourceAddress: datagram.address.address,
            );
            if (parsed != null) devices[parsed.key] = parsed;
          });
          socket.send(utf8.encode(_probeMessage()), _multicastAddress, 3702);
          var elapsed = Duration.zero;
          while (elapsed < listenDuration && !(isCancelled?.call() ?? false)) {
            const interval = Duration(milliseconds: 100);
            await Future<void>.delayed(interval);
            elapsed += interval;
          }
        } on Object {
          continue;
        } finally {
          await subscription?.cancel();
          socket?.close();
        }
      }
    }
    return devices.values.toList(growable: false);
  }

  Future<OnvifDevice?> loadProfiles(
    OnvifProbeDevice device, {
    required String username,
    required String password,
    Duration timeout = const Duration(seconds: 3),
    bool Function()? isCancelled,
  }) async {
    final capabilityFuture = _soapRequest(
      device.deviceServiceUri,
      _deviceAction,
      '<tds:GetCapabilities><tds:Category>Media</tds:Category></tds:GetCapabilities>',
      username: username,
      password: password,
      timeout: timeout,
    );
    final informationFuture = _soapRequest(
      device.deviceServiceUri,
      _deviceInformationAction,
      '<tds:GetDeviceInformation/>',
      username: username,
      password: password,
      timeout: timeout,
    );
    final capabilityResponse = await capabilityFuture;
    final informationResponse = await informationFuture;
    if (isCancelled?.call() ?? false) return null;
    if (capabilityResponse == null) return null;
    final information = parseDeviceInformation(informationResponse ?? '');
    final mediaUri =
        _mediaServiceUri(capabilityResponse) ?? device.deviceServiceUri;
    final profilesResponse = await _soapRequest(
      mediaUri,
      _mediaProfilesAction,
      '<trt:GetProfiles/>',
      username: username,
      password: password,
      timeout: timeout,
    );
    if (profilesResponse == null) return null;
    final profilesDocument = XmlDocument.parse(profilesResponse);
    final profileElements = _descendants(profilesDocument)
        .where((element) => element.name.local == 'Profiles')
        .toList(growable: false);
    final profiles = <OnvifProfile>[];
    for (final profile in profileElements) {
      if (isCancelled?.call() ?? false) return null;
      final token = _attribute(profile, 'token');
      if (token == null || token.isEmpty) continue;
      final video = _firstDescendant(profile, 'VideoEncoderConfiguration');
      final resolution = video == null
          ? null
          : _firstDescendant(video, 'Resolution');
      final width = _intChild(resolution, 'Width');
      final height = _intChild(resolution, 'Height');
      final frameRate = _intChild(video, 'FrameRateLimit');
      final encoding = _textChild(video, 'Encoding');
      final source = _firstDescendant(profile, 'VideoSourceConfiguration');
      final sourceToken = source == null
          ? null
          : _textChild(source, 'SourceToken');
      final uriResponse = await _soapRequest(
        mediaUri,
        _streamUriAction,
        '<trt:GetStreamUri><trt:StreamSetup><tt:Stream>RTP-Unicast</tt:Stream><tt:Transport><tt:Protocol>RTSP</tt:Protocol></tt:Transport></trt:StreamSetup><trt:ProfileToken>${_escapeXml(token)}</trt:ProfileToken></trt:GetStreamUri>',
        username: username,
        password: password,
        timeout: timeout,
      );
      if (uriResponse == null) continue;
      final streamText = _textElement(XmlDocument.parse(uriResponse), 'Uri');
      final streamUri = Uri.tryParse(streamText ?? '');
      if (streamUri == null || streamUri.scheme.toLowerCase() != 'rtsp') {
        continue;
      }
      profiles.add(
        OnvifProfile(
          token: token,
          name: _textChild(profile, 'Name') ?? token,
          sourceToken: sourceToken,
          streamUri: streamUri,
          width: width,
          height: height,
          framesPerSecond: frameRate,
          encoding: encoding,
        ),
      );
    }
    if (profiles.isEmpty) return null;
    return OnvifDevice(
      host: device.sourceAddress,
      deviceServiceUri: device.deviceServiceUri,
      name: device.name,
      manufacturer: information.$1,
      model: information.$2,
      profiles: profiles,
    );
  }

  static (String?, String?) parseDeviceInformation(String xml) {
    try {
      final document = XmlDocument.parse(xml);
      return (
        _textElement(document, 'Manufacturer'),
        _textElement(document, 'Model'),
      );
    } on Object {
      return (null, null);
    }
  }

  static OnvifProbeDevice? parseProbeResponse(
    String xml, {
    required String sourceAddress,
  }) {
    try {
      final document = XmlDocument.parse(xml);
      final addressText = _textElement(document, 'XAddrs');
      if (addressText == null) return null;
      final addresses = addressText
          .split(RegExp(r'\s+'))
          .map(Uri.tryParse)
          .whereType<Uri>()
          .where((uri) => uri.scheme == 'http' || uri.scheme == 'https')
          .toList(growable: false);
      if (addresses.isEmpty) return null;
      final scopes = _textElement(document, 'Scopes') ?? '';
      final nameScope = scopes.split(RegExp(r'\s+')).where((scope) {
        return scope.contains('/name/');
      }).firstOrNull;
      final name = nameScope == null
          ? null
          : Uri.decodeComponent(nameScope.split('/name/').last);
      return OnvifProbeDevice(
        sourceAddress: sourceAddress,
        deviceServiceUri: addresses.first,
        name: name,
      );
    } on Object {
      return null;
    }
  }

  Future<String?> _soapRequest(
    Uri uri,
    String action,
    String body, {
    required String username,
    required String password,
    required Duration timeout,
  }) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client.postUrl(uri).timeout(timeout);
      request.headers.set(
        HttpHeaders.contentTypeHeader,
        'application/soap+xml; charset=utf-8; action="$action"',
      );
      request.headers.set(HttpHeaders.acceptHeader, 'application/soap+xml');
      request.write(
        _soapEnvelope(body, username: username, password: password),
      );
      final response = await request.close().timeout(timeout);
      final content = await utf8.decoder.bind(response).join().timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      return content;
    } on Object {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  Uri? _mediaServiceUri(String xml) {
    try {
      final document = XmlDocument.parse(xml);
      final media = _descendants(
        document,
      ).where((element) => element.name.local == 'Media');
      for (final service in media) {
        final endpoint = _textChild(service, 'XAddr');
        final uri = Uri.tryParse(endpoint ?? '');
        if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
          return uri;
        }
      }
    } on Object {
      return null;
    }
    return null;
  }

  String _soapEnvelope(
    String body, {
    required String username,
    required String password,
  }) {
    final security = username.isEmpty ? '' : _usernameToken(username, password);
    return '<s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope" xmlns:a="http://www.w3.org/2005/08/addressing" xmlns:tds="http://www.onvif.org/ver10/device/wsdl" xmlns:trt="http://www.onvif.org/ver10/media/wsdl" xmlns:tt="http://www.onvif.org/ver10/schema" xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd" xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd"><s:Header>$security</s:Header><s:Body>$body</s:Body></s:Envelope>';
  }

  String _usernameToken(String username, String password) {
    final nonce = List<int>.generate(20, (_) => Random.secure().nextInt(256));
    final created = DateTime.now().toUtc().toIso8601String();
    final digest = base64.encode(
      sha1.convert([
        ...nonce,
        ...utf8.encode(created),
        ...utf8.encode(password),
      ]).bytes,
    );
    return '<wsse:Security s:mustUnderstand="1"><wsse:UsernameToken><wsse:Username>${_escapeXml(username)}</wsse:Username><wsse:Password Type="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-username-token-profile-1.0#PasswordDigest">$digest</wsse:Password><wsse:Nonce EncodingType="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-soap-message-security-1.0#Base64Binary">${base64.encode(nonce)}</wsse:Nonce><wsu:Created>$created</wsu:Created></wsse:UsernameToken></wsse:Security>';
  }

  String _probeMessage() {
    final nonce = Random.secure().nextInt(1 << 32);
    return '<?xml version="1.0" encoding="UTF-8"?><e:Envelope xmlns:e="http://www.w3.org/2003/05/soap-envelope" xmlns:w="http://schemas.xmlsoap.org/ws/2004/08/addressing" xmlns:d="http://schemas.xmlsoap.org/ws/2005/04/discovery" xmlns:dn="http://www.onvif.org/ver10/network/wsdl"><e:Header><w:MessageID>uuid:${DateTime.now().microsecondsSinceEpoch}-$nonce</w:MessageID><w:To>urn:schemas-xmlsoap-org:ws:2005:04:discovery</w:To><w:Action>http://schemas.xmlsoap.org/ws/2005/04/discovery/Probe</w:Action></e:Header><e:Body><d:Probe><d:Types>dn:NetworkVideoTransmitter</d:Types></d:Probe></e:Body></e:Envelope>';
  }

  static Iterable<XmlElement> _descendants(XmlNode node) =>
      node.descendants.whereType<XmlElement>();

  static XmlElement? _firstDescendant(XmlNode? node, String localName) =>
      node == null
      ? null
      : _descendants(
          node,
        ).where((element) => element.name.local == localName).firstOrNull;

  static String? _textElement(XmlNode node, String localName) =>
      _firstDescendant(node, localName)?.innerText.trim();

  static String? _textChild(XmlNode? node, String localName) =>
      _firstDescendant(node, localName)?.innerText.trim();

  static int? _intChild(XmlNode? node, String localName) =>
      int.tryParse(_textChild(node, localName) ?? '');

  static String? _attribute(XmlElement element, String localName) => element
      .attributes
      .where((attribute) => attribute.name.local == localName)
      .firstOrNull
      ?.value;

  static String _escapeXml(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}

class OnvifProbeDevice {
  const OnvifProbeDevice({
    required this.sourceAddress,
    required this.deviceServiceUri,
    required this.name,
    this.manufacturer,
    this.model,
  });

  final String sourceAddress;
  final Uri deviceServiceUri;
  final String? name;
  final String? manufacturer;
  final String? model;
  String get key => '${deviceServiceUri.host}:${deviceServiceUri.port}';
}

class OnvifDevice {
  const OnvifDevice({
    required this.host,
    required this.deviceServiceUri,
    required this.name,
    this.manufacturer,
    this.model,
    required this.profiles,
  });

  final String host;
  final Uri deviceServiceUri;
  final String? name;
  final String? manufacturer;
  final String? model;
  final List<OnvifProfile> profiles;
}

class OnvifStreamPair {
  const OnvifStreamPair({
    required this.sourceKey,
    required this.main,
    required this.sub,
  });

  final String sourceKey;
  final OnvifProfile main;
  final OnvifProfile? sub;

  /// Reduz os perfis ONVIF a um fluxo principal e um subfluxo por fonte de
  /// vídeo. Perfis com o mesmo URI, ou fontes que repetem exatamente os
  /// mesmos fluxos, são descartados. O subfluxo é o primeiro perfil com
  /// resolução menor que a do principal.
  static List<OnvifStreamPair> group(List<OnvifProfile> profiles) {
    final uniqueByUri = <String, OnvifProfile>{};
    for (final profile in profiles) {
      uniqueByUri.putIfAbsent(profile.streamUri.toString(), () => profile);
    }
    final groups = <String, List<OnvifProfile>>{};
    for (final profile in uniqueByUri.values) {
      final source = profile.sourceToken?.trim();
      final key = source == null || source.isEmpty ? '' : source;
      groups.putIfAbsent(key, () => []).add(profile);
    }
    if (groups.length > 1 && groups.containsKey('')) {
      final orphan = groups.remove('')!;
      groups.values.first.addAll(orphan);
    }
    final seenSignatures = <String>{};
    final result = <OnvifStreamPair>[];
    for (final entry in groups.entries) {
      final sorted = [...entry.value]
        ..sort((left, right) => right.pixelCount.compareTo(left.pixelCount));
      final main = sorted.first;
      OnvifProfile? sub;
      for (final candidate in sorted.skip(1)) {
        if (candidate.pixelCount < main.pixelCount ||
            (main.pixelCount == 0 && candidate.streamUri != main.streamUri)) {
          sub = candidate;
          break;
        }
      }
      final signature = '${main.streamUri}|${sub?.streamUri}';
      if (!seenSignatures.add(signature)) continue;
      result.add(OnvifStreamPair(sourceKey: entry.key, main: main, sub: sub));
    }
    return result;
  }
}

class OnvifProfile {
  const OnvifProfile({
    required this.token,
    required this.name,
    required this.sourceToken,
    required this.streamUri,
    required this.width,
    required this.height,
    required this.framesPerSecond,
    required this.encoding,
  });

  final String token;
  final String name;
  final String? sourceToken;
  final Uri streamUri;
  final int? width;
  final int? height;
  final int? framesPerSecond;
  final String? encoding;

  int get pixelCount => (width ?? 0) * (height ?? 0);

  String get quality => [
    if (width != null && height != null) '$width×$height',
    if (framesPerSecond != null && framesPerSecond! > 0) '$framesPerSecond fps',
    if (encoding != null && encoding!.isNotEmpty) encoding!.toUpperCase(),
  ].join(' · ');
}
