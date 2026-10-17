import 'package:flutter/material.dart';

import '../../../../app/state/app_store.dart';

class MonitorProfileStatus extends StatefulWidget {
  const MonitorProfileStatus({this.showWhenUnchanged = true, super.key});
  final bool showWhenUnchanged;

  @override
  State<MonitorProfileStatus> createState() => _MonitorProfileStatusState();
}

class _MonitorProfileStatusState extends State<MonitorProfileStatus> {
  bool _busy = false;

  Future<void> _run(Future<bool> Function() operation, String success) async {
    if (_busy) return;
    final store = AppScope.of(context);
    setState(() => _busy = true);
    final saved = await operation();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? success
              : store.message ?? 'Não foi possível salvar o perfil.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final profile = store.activeMonitorProfile;
    final modified = store.isMonitorProfileModified;
    if (profile == null || (!modified && !widget.showWhenUnchanged)) {
      return const SizedBox.shrink();
    }
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${profile.name} · ${modified ? 'Modificado' : 'Salvo'}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              modified
                  ? 'A grade atual tem alterações que ainda não foram salvas neste perfil.'
                  : 'A grade corresponde à versão salva.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
            if (modified) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _run(
                            () => store.saveMonitorProfile(
                              id: profile.id,
                              name: profile.name,
                            ),
                            'Alterações do perfil salvas.',
                          ),
                    icon: const Icon(Icons.save_outlined),
                    label: Text(_busy ? 'Processando…' : 'Salvar alterações'),
                  ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => _run(
                            () => store.applyMonitorProfile(profile.id),
                            'Versão salva restaurada.',
                          ),
                    child: const Text('Restaurar versão salva'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
