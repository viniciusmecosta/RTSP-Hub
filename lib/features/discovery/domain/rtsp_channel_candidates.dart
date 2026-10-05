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
