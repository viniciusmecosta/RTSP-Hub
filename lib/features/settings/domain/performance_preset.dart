enum PerformancePreset {
  light(
    id: 'light',
    label: 'Leve',
    bufferMs: 180,
    description:
        'Subfluxos e cache reduzido para computadores básicos. A resolução original do fluxo é preservada.',
  ),
  balanced(
    id: 'balanced',
    label: 'Equilibrado',
    bufferMs: 400,
    description:
        'Subfluxos com mais cache para tolerar oscilações da rede. A resolução original do fluxo é preservada.',
  ),
  quality(
    id: 'quality',
    label: 'Qualidade',
    bufferMs: 800,
    description: 'Usa fluxos principais para priorizar a qualidade da imagem.',
  );

  const PerformancePreset({
    required this.id,
    required this.label,
    required this.bufferMs,
    required this.description,
  });

  final String id;
  final String label;
  final int bufferMs;
  final String description;

  static PerformancePreset fromId(String? id) => switch (id) {
    'eco' || 'light' => light,
    'balanced' => balanced,
    'quality' => quality,
    _ => light,
  };
}
