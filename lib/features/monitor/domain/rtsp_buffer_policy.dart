class RtspBufferPolicy {
  static int bytesFor({
    required int targetMilliseconds,
    required bool mainStream,
  }) {
    final minimum = mainStream ? 512 * 1024 : 256 * 1024;
    final estimated =
        targetMilliseconds.clamp(100, 2000) * (mainStream ? 1024 : 512);
    return estimated.clamp(minimum, 4 * 1024 * 1024);
  }
}
