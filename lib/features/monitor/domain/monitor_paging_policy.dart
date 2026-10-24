class MonitorPagingPolicy {
  static const choices = {-1, 0, 1, 2, 4, 6, 9, 16};

  static int pageSize({
    required int cameraCount,
    required int preference,
    required bool television,
  }) {
    final count = cameraCount < 1 ? 1 : cameraCount;
    final selected = choices.contains(preference) ? preference : 0;
    if (selected == -1 || (selected == 0 && !television)) return count;
    return (selected == 0 ? 4 : selected).clamp(1, count);
  }
}
