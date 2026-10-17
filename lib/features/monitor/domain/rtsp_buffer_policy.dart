class RtspBufferPolicy {
  static int bytesFor({
    required int targetMilliseconds,
    required bool mainStream,
  }) {
    final minimum = mainStream ? 256 * 1024 : 128 * 1024;
    final estimated =
        targetMilliseconds.clamp(100, 2000) * (mainStream ? 2048 : 1024);
    return estimated.clamp(minimum, 4 * 1024 * 1024);
  }
}
