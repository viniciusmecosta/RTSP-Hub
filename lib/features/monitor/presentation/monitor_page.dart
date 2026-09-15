import 'package:flutter/material.dart';

import '../../../shared/design_system/page_frame.dart';

class MonitorPage extends StatelessWidget {
  const MonitorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'Monitor',
      subtitle: 'Visualização das câmeras em tempo real.',
      child: const EmptyPanel(
        icon: Icons.monitor_outlined,
        title: 'Monitor pronto para configurar',
        description:
            'Cadastre câmeras e atribua ao layout para iniciar a transmissão.',
      ),
    );
  }
}
