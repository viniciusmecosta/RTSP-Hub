import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class TransferScanPage extends StatefulWidget {
  const TransferScanPage({super.key});
  @override
  State<TransferScanPage> createState() => _TransferScanPageState();
}

class _TransferScanPageState extends State<TransferScanPage>
    with WidgetsBindingObserver {
  final _controller = MobileScannerController(
    autoStart: false,
    formats: [BarcodeFormat.qrCode],
  );
  bool _received = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    if (!mounted || _received) return;
    try {
      await _controller.start();
    } on Object {
      if (mounted) {
        setState(
          () => _error =
              'Não foi possível abrir a câmera. Permita o acesso nas configurações do aparelho ou importe pelo código.',
        );
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_start());
    } else {
      unawaited(_controller.stop());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ler QR Code')),
    body: Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Aponte para o QR Code exibido no outro aparelho. Você confirmará a importação antes de salvar.',
          ),
        ),
        Expanded(
          child: _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!),
                  ),
                )
              : MobileScanner(
                  controller: _controller,
                  useAppLifecycleState: false,
                  errorBuilder: (context, error) => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Câmera indisponível. Confira a permissão ou volte e cole o código.',
                      ),
                    ),
                  ),
                  onDetect: (capture) async {
                    final value = capture.barcodes
                        .map((b) => b.rawValue)
                        .whereType<String>()
                        .firstOrNull;
                    if (_received || value == null) return;
                    _received = true;
                    await _controller.stop();
                    if (context.mounted) Navigator.pop(context, value);
                  },
                ),
        ),
      ],
    ),
  );
}
