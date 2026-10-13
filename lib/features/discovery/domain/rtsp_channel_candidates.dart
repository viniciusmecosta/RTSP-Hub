class RtspChannelCandidates {
  static const paths = <String>[
    '/Streaming/Channels/101',
    '/Streaming/Channels/102',
    '/cam/realmonitor?channel=1&subtype=0',
    '/cam/realmonitor?channel=1&subtype=1',
    '/media/video1',
    '/media/video2',
    '/live/ch00_0',
    '/stream1',
    '/h264',
    '/1/1',
  ];

  static List<String> forChannel(int channel) {
    if (channel < 1 || channel > 255) return const [];
    return [
      '/Streaming/Channels/${channel}01',
      '/cam/realmonitor?channel=$channel&subtype=0',
      ...subForChannel(channel),
      ...paths.skip(4),
    ];
  }

  static List<String> mainForChannel(int channel, {String? preferredPath}) {
    if (channel < 1 || channel > 255) return const [];
    return {
      if (preferredPath != null && preferredPath.isNotEmpty) preferredPath,
      '/Streaming/Channels/${channel}01',
      '/cam/realmonitor?channel=$channel&subtype=0',
      if (channel == 1) ...paths.skip(4),
    }.toList(growable: false);
  }

  static List<String> subForChannel(int channel, {String? preferredPath}) {
    if (channel < 1 || channel > 255) return const [];
    return {
      if (preferredPath != null && preferredPath.isNotEmpty) preferredPath,
      '/Streaming/Channels/${channel}02',
      '/cam/realmonitor?channel=$channel&subtype=1',
    }.toList(growable: false);
  }
}

/// Identifica um fluxo pelo que realmente foi recebido (resolução, fps e
/// codec), ignorando a taxa de bits que oscila entre leituras.
class StreamSignature {
  static final _resolution = RegExp(r'(\d{2,5})\s*[×x]\s*(\d{2,5})');

  static String resolution(String quality) {
    final match = _resolution.firstMatch(quality);
    return match == null ? '' : '${match.group(1)}x${match.group(2)}';
  }

  static String of(String mainQuality, String? subQuality) {
    String normalize(String value) => value
        .split('·')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty && !part.endsWith('Mbps'))
        .join('|')
        .toLowerCase();
    return '${normalize(mainQuality)}#${normalize(subQuality ?? '')}';
  }
}
