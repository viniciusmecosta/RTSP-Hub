import 'package:material_ui/material_ui.dart';

Future<bool?> askExportCredentials(BuildContext context) => showDialog<bool>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Incluir usuário e senha?'),
    content: const Text(
      'Quem receber poderá acessar suas câmeras. Com credenciais, o arquivo ou QR Code contém dados de acesso legíveis. Compartilhe apenas com pessoas de confiança.',
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, true),
        child: const Text('Incluir credenciais'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Sem credenciais'),
      ),
    ],
  ),
);
