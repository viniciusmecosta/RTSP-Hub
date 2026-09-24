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
      '/Streaming/Channels/${channel}02',
      '/cam/realmonitor?channel=$channel&subtype=0',
      '/cam/realmonitor?channel=$channel&subtype=1',
      ...paths.skip(4),
    ];
  }
}
