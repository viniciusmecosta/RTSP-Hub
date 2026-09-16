import 'package:flutter/material.dart';

import '../../../app/state/app_store.dart';
import '../../../shared/design_system/page_frame.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({
    required this.onAddCamera,
    required this.onOpenMonitor,
    super.key,
  });

  final VoidCallback onAddCamera;
  final VoidCallback onOpenMonitor;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final store = AppScope.of(context);
    final columns = width >= 1100
        ? 3
        : width >= 700
        ? 2
        : 1;
    return PageFrame(
      title: 'Visão geral',
      subtitle: 'Seu monitoramento local, organizado em um só lugar.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 560;
                final content = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Comece pelo essencial',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Cadastre suas câmeras, teste a conexão e prepare uma grade de monitoramento.',
                      style: TextStyle(color: Color(0xFFE0EAFF), height: 1.45),
                    ),
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      onPressed: onAddCamera,
                      icon: const Icon(Icons.add),
                      label: const Text('Adicionar câmera'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF1D4ED8),
                      ),
                    ),
                    if (store.cameras.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: onOpenMonitor,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Abrir monitor'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Color(0x99FFFFFF)),
                        ),
                      ),
                    ],
                  ],
                );
                if (narrow) return content;
                return Row(
                  children: [
                    Expanded(child: content),
                    const SizedBox(width: 24),
                    const Icon(
                      Icons.videocam_rounded,
                      size: 104,
                      color: Color(0x66FFFFFF),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: columns,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: columns == 1 ? 2.9 : 2.1,
            children: [
              _OverviewCard(
                icon: Icons.videocam_outlined,
                title: 'Câmeras',
                value: '${store.cameras.length} cadastradas',
                color: Color(0xFF2563EB),
              ),
              _OverviewCard(
                icon: Icons.grid_view_rounded,
                title: 'Layout ativo',
                value: store.activeLayout.name,
                color: Color(0xFF7C3AED),
              ),
              _OverviewCard(
                icon: Icons.shield_outlined,
                title: 'Dados',
                value: 'Armazenados neste dispositivo',
                color: Color(0xFF059669),
              ),
            ],
          ),
          const SizedBox(height: 20),
          EmptyPanel(
            icon: store.cameras.isEmpty
                ? Icons.desktop_windows_outlined
                : Icons.live_tv_outlined,
            title: store.cameras.isEmpty
                ? 'Seu monitor estará aqui'
                : 'Pronto para visualizar',
            description: store.cameras.isEmpty
                ? 'Adicione uma câmera e escolha um layout para abrir a visualização ao vivo.'
                : 'Abra o monitor para visualizar as câmeras selecionadas na grade ${store.activeLayout.name.toLowerCase()}.',
            action: store.cameras.isEmpty
                ? null
                : FilledButton.icon(
                    onPressed: onOpenMonitor,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Abrir monitor'),
                  ),
          ),
        ],
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
