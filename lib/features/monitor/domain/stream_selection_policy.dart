class StreamSelectionPolicy {
  static bool useMainStream({
    required String resourceMode,
    bool? manualChoice,
    bool focused = false,
    bool hasSubStream = true,
  }) =>
      !hasSubStream || (manualChoice ?? (focused || resourceMode == 'quality'));
}
