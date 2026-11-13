import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../app/data/transfer_codec.dart';
import 'transfer_file.dart';

class TransferExportDialog extends StatelessWidget {
  TransferExportDialog({
    required this.json,
    required this.includesCredentials,
    super.key,
  }) : code = TransferCodec.encode(json);
  final String json, code;
  final bool includesCredentials;

  Future<void> _save(BuildContext context, bool compact) async {
    try {
      await saveTransferFile(context, compact ? code : json, compact: compact);
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível salvar o arquivo. Confira o acesso à pasta.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Compartilhar configuração'),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              includesCredentials
                  ? 'Inclui credenciais. Mostre este QR apenas para quem pode acessar suas câmeras.'
                  : 'Sem credenciais. O destinatário precisará informar o acesso às câmeras.',
            ),
            const SizedBox(height: 12),
            if (code.length <= TransferCodec.maxQrCharacters)
              LayoutBuilder(
                builder: (context, constraints) => Center(
                  child: QrImageView(
                    data: code,
                    size: constraints.maxWidth.clamp(180, 420),
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.all(18),
                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                    semanticsLabel: 'QR Code da configuração do RTSP Hub',
                    errorStateBuilder: (_, _) => const Text(
                      'Use o código ou arquivo para transferir esta configuração.',
                    ),
                  ),
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Esta configuração é grande demais para um QR legível. Copie o código ou envie o arquivo compacto.',
                ),
              ),
            const SizedBox(height: 12),
            Text('Código compacto: ${code.length} caracteres.'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: code));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Código compacto copiado.'),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copiar código'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _save(context, true),
                  icon: const Icon(Icons.save_alt),
                  label: const Text('Arquivo compacto'),
                ),
                TextButton.icon(
                  onPressed: () => _save(context, false),
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('Arquivo JSON'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Fechar'),
      ),
    ],
  );
}
