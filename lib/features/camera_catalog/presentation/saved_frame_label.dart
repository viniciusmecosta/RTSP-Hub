String savedFrameLabel(DateTime? capturedAt) {
  if (capturedAt == null) return 'Imagem salva · data não registrada';
  final local = capturedAt.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return 'Imagem salva · ${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
}
