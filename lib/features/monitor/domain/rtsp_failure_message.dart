import 'dart:async';

class RtspFailureMessage {
  static bool canRetry(Object failure) {
    final text = failure.toString().toLowerCase();
    return failure is! FormatException &&
        !text.contains('401') &&
        !text.contains('403') &&
        !text.contains('404') &&
        !text.contains('unauthorized') &&
        !text.contains('authentication') &&
        !text.contains('auth failed') &&
        !text.contains('access denied') &&
        !text.contains('not found') &&
        !text.contains('invalid character') &&
        !text.contains('invalid uri') &&
        !text.contains('unsupported codec');
  }

  static String describe(Object failure) {
    final text = failure.toString().toLowerCase();
    if (failure is TimeoutException ||
        text.contains('timed out') ||
        text.contains('timeout')) {
      return 'A câmera não respondeu a tempo. Confira a rede, a porta e se o fluxo está ativo.';
    }
    if (text.contains('401') ||
        text.contains('unauthorized') ||
        text.contains('authentication') ||
        text.contains('auth failed') ||
        text.contains('access denied')) {
      return 'A câmera recusou o usuário ou a senha. Confira as credenciais usadas neste dispositivo.';
    }
    if (text.contains('connection refused') ||
        text.contains('actively refused')) {
      return 'A câmera recusou a conexão. Confira a porta RTSP e se o serviço está habilitado.';
    }
    if (text.contains('no route to host') ||
        text.contains('network is unreachable') ||
        text.contains('host is unreachable') ||
        text.contains('name or service not known')) {
      return 'Não foi possível alcançar a câmera. Confira o endereço e se o dispositivo está na mesma rede.';
    }
    if (text.contains('404') || text.contains('not found')) {
      return 'O caminho RTSP não foi encontrado. Escolha outro canal ou revise o caminho do fluxo.';
    }
    if (failure is FormatException ||
        text.contains('invalid character') ||
        text.contains('invalid uri')) {
      return 'O endereço RTSP contém um valor inválido. Revise o usuário, a senha e o caminho do fluxo.';
    }
    if (text.contains('unsupported') ||
        text.contains('invalid data') ||
        text.contains('codec')) {
      return 'O fluxo usa um formato que não pôde ser reproduzido. Tente o fluxo secundário ou outro perfil da câmera.';
    }
    return 'Não foi possível receber o vídeo. Confira as credenciais, o caminho RTSP e a conexão da câmera.';
  }
}
