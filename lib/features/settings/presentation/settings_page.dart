import 'package:flutter/material.dart';

import '../../../app/state/app_store.dart';
import '../../../shared/design_system/page_frame.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    return PageFrame(
      title: 'Ajustes',
      subtitle: 'Aparência e uso de recursos neste dispositivo.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text('Aparência'),
                  subtitle: const Text('Tema claro, escuro ou automático'),
                  trailing: DropdownButton<ThemeMode>(
                    value: store.themeMode,
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
                    onChanged: (mode) {
                      if (mode != null) store.setThemeMode(mode);
                    },
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.memory_outlined),
                  title: const Text('Perfil de desempenho'),
                  subtitle: const Text(
                    'Baixa latência usa menos buffer; fluxo secundário reduz o trabalho do computador.',
                  ),
                  trailing: DropdownButton<String>(
                    value: store.config.resourceMode,
                    items: const [
                      DropdownMenuItem(value: 'eco', child: Text('Econômico')),
                      DropdownMenuItem(
                        value: 'balanced',
                        child: Text('Equilibrado'),
                      ),
                      DropdownMenuItem(
                        value: 'quality',
                        child: Text('Qualidade'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        store.updateSettings(
                          resourceMode: value,
                          bufferMs: value == 'eco'
                              ? 250
                              : value == 'balanced'
                              ? 500
                              : 900,
                        );
                      }
                    },
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.high_quality_outlined),
                  title: const Text('Buffer de reprodução'),
                  subtitle: Text(
                    '${store.config.bufferMs} ms · menor valor reduz atraso e memória, mas pode causar interrupções em redes instáveis.',
                  ),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.lock_outline),
                  title: Text('Credenciais protegidas'),
                  subtitle: Text(
                    'Senhas são guardadas no cofre seguro do sistema e nunca no arquivo de configuração.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                'Em computadores com pouca memória, prefira o fluxo secundário da câmera e o perfil Econômico. O número de transmissões simultâneas também depende da câmera, da rede e do decodificador disponível.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
