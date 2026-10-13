import '../../monitor/application/rtsp_session.dart';

/// Descreve o vídeo recebido por uma sessão de teste (resolução, fps, codec
/// e taxa de bits), usado para diferenciar fluxo principal e subfluxo.
String describeStreamQuality(RtspSession session) {
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
    if (track.fps case final fps? when fps > 0) '${fps.toStringAsFixed(1)} fps',
    if (track.codec case final codec? when codec.isNotEmpty)
      codec.toUpperCase(),
    if (track.bitrate case final int bitrate when bitrate > 0)
      '${(bitrate / 1000000).toStringAsFixed(1)} Mbps',
  ];
  return details.isEmpty ? 'Vídeo detectado' : details.join(' · ');
}
