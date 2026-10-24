class StreamSelectionPolicy {
  static bool useMainStream({
    required String resourceMode,
    bool? manualChoice,
    bool focused = false,
    bool hasSubStream = true,
    bool upgradeFocusedStream = true,
  }) =>
      !hasSubStream ||
      (manualChoice ??
          ((focused && upgradeFocusedStream) || resourceMode == 'quality'));
}
