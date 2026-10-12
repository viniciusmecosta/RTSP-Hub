enum PerformancePreset {
  light(
    id: 'light',
    label: 'Leve',
    bufferMs: 180,
    maxConcurrentStreams: 4,
    description:
        'Prioriza fluidez em computadores básicos e fluxos secundários.',
  ),
  balanced(
    id: 'balanced',
    label: 'Equilibrado',
    bufferMs: 400,
    maxConcurrentStreams: 9,
    description: 'Equilibra qualidade e consumo para até nove câmeras.',
  ),
  quality(
    id: 'quality',
    label: 'Qualidade',
    bufferMs: 800,
    maxConcurrentStreams: 16,
    description: 'Usa fluxos principais e mantém mais câmeras decodificadas.',
  );

  const PerformancePreset({
    required this.id,
    required this.label,
    required this.bufferMs,
    required this.maxConcurrentStreams,
    required this.description,
  });

  final String id;
  final String label;
  final int bufferMs;
  final int maxConcurrentStreams;
  final String description;

  static PerformancePreset fromId(String? id) => switch (id) {
    'eco' || 'light' => light,
    'balanced' => balanced,
    'quality' => quality,
    _ => light,
  };
}
