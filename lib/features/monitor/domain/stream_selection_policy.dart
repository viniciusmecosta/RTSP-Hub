class StreamSelectionPolicy {
  static bool useMainStream({
    required String resourceMode,
    String defaultStreamMode = 'auto',
    bool? manualChoice,
    bool focused = false,
    bool hasSubStream = true,
    bool upgradeFocusedStream = true,
  }) {
    if (!hasSubStream) return true;
    if (manualChoice != null) return manualChoice;
    if (focused && upgradeFocusedStream) return true;
    if (defaultStreamMode == 'main') return true;
    if (defaultStreamMode == 'sub') return false;
    return resourceMode == 'quality';
  }
}
