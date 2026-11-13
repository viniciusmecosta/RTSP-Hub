import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import '../../../app/data/transfer_codec.dart';
import 'transfer_scan_page.dart';

Future<String?> readTransferSource(BuildContext context) => showDialog<String>(
  context: context,
  builder: (context) => const _TransferImportDialog(),
);

class _TransferImportDialog extends StatefulWidget {
  const _TransferImportDialog();
  @override
  State<_TransferImportDialog> createState() => _TransferImportDialogState();
}

class _TransferImportDialogState extends State<_TransferImportDialog> {
  final _code = TextEditingController();
  String? _error;
  bool _busy = false;
  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _read(bool scan) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      String? source;
      if (scan) {
        source = await Navigator.of(context).push<String>(
          MaterialPageRoute(builder: (_) => const TransferScanPage()),
        );
      } else {
        final file = await openFile(
          acceptedTypeGroups: const [
            XTypeGroup(
              label: 'Configuração RTSP Hub',
              extensions: ['rth', 'json', 'txt'],
            ),
          ],
        );
        if (file != null) {
          if (await file.length() > TransferCodec.maxCodeCharacters) {
            throw const FormatException();
          }
          source = await file.readAsString();
        }
      }
      if (mounted && source != null) Navigator.pop(context, source);
    } on Object {
      if (mounted) {
        setState(
          () => _error =
              'Não foi possível abrir. Escolha um arquivo do RTSP Hub ou cole o código.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scanSupported =
        Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
    return AlertDialog(
      title: const Text('Importar configuração'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _read(false),
                    icon: const Icon(Icons.file_open),
                    label: const Text('Abrir arquivo'),
                  ),
                  if (scanSupported)
                    FilledButton.icon(
                      onPressed: _busy ? null : () => _read(true),
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Ler QR Code'),
                    ),
                ],
              ),
              if (!scanSupported)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Neste computador, receba o arquivo ou cole o código. Para ler com a câmera, use Android, iPhone ou macOS.',
                  ),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _code,
                minLines: 3,
                maxLines: 6,
                maxLength: TransferCodec.maxCodeCharacters,
                decoration: const InputDecoration(
                  labelText: 'Cole o código compacto ou JSON',
                ),
                autocorrect: false,
                enableSuggestions: false,
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _busy
              ? null
              : () {
                  if (_code.text.trim().isEmpty) {
                    setState(() => _error = 'Cole o código recebido.');
                    return;
                  }
                  Navigator.pop(context, _code.text);
                },
          child: const Text('Continuar'),
        ),
      ],
    );
  }
}
