import 'package:flutter/material.dart';

import '../../../shared/design_system/page_frame.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'Ajustes',
      subtitle: 'Preferências de aparência, conexão e consumo de recursos.',
      child: Card(
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('Aparência'),
              subtitle: const Text('Tema claro, escuro ou automático'),
              trailing: DropdownButton<ThemeMode>(
                value: ThemeMode.system,
                items: const [
                  DropdownMenuItem(
                    value: ThemeMode.system,
                    child: Text('Sistema'),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.light,
                    child: Text('Claro'),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.dark,
                    child: Text('Escuro'),
                  ),
                ],
                onChanged: (_) {},
              ),
            ),
            const Divider(height: 1),
            const ListTile(
              leading: Icon(Icons.bolt_outlined),
              title: Text('Modo de recursos'),
              subtitle: Text(
                'Perfil equilibrado para visualizar até 4 câmeras.',
              ),
            ),
            const Divider(height: 1),
            const ListTile(
              leading: Icon(Icons.lock_outline),
              title: Text('Credenciais protegidas'),
              subtitle: Text(
                'Senhas ficam no armazenamento seguro do dispositivo.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
