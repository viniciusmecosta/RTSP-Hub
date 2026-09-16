import 'dart:io';

class CameraFieldValidation {
  static String? hostError(String value) {
    final host = value.trim();
    if (host.isEmpty) return 'Informe o endereço da câmera.';
    if (host.contains('://') || host.contains('/') || host.contains('@')) {
      return 'Informe apenas um endereço IP ou host.';
    }
    if (InternetAddress.tryParse(host) != null) return null;
    if (host.length > 253 || host.startsWith('.') || host.endsWith('.')) {
      return 'Confira o endereço da câmera.';
    }
    final valid = host
        .split('.')
        .every(
          (label) =>
              label.isNotEmpty &&
              label.length <= 63 &&
              RegExp(
                r'^[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?$',
              ).hasMatch(label),
        );
    return valid ? null : 'Informe um endereço IP ou nome de host válido.';
  }

  static String? portError(String value) {
    if (value.trim().isEmpty) return null;
    final port = int.tryParse(value.trim());
    return port == null || port < 1 || port > 65535
        ? 'A porta deve ser um número entre 1 e 65535.'
        : null;
  }

  static String? pathError(String value, {bool optional = false}) {
    final path = value.trim();
    if (optional && path.isEmpty) return null;
    if (!path.startsWith('/') ||
        path.startsWith('//') ||
        path.length > 1024 ||
        path.contains('#') ||
        path.contains('://') ||
        path.contains('\n') ||
        path.contains('\r')) {
      return 'Use um caminho RTSP iniciado por / e sem fragmento.';
    }
    return null;
  }
}
