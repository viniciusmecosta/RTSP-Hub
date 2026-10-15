class FoundChannel {
  const FoundChannel({
    required this.number,
    required this.mainPath,
    required this.mainQuality,
    required this.subPath,
    required this.subQuality,
  });

  final int number;
  final String mainPath;
  final String mainQuality;
  final String? subPath;
  final String? subQuality;
}
