import 'package:flutter/material.dart';

import '../../../shared/design_system/page_frame.dart';

class CameraCatalogPage extends StatelessWidget {
  const CameraCatalogPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'Câmeras',
      subtitle: 'Cadastre endereços RTSP e valide o vídeo antes de monitorar.',
      actions: [
        FilledButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.add),
          label: const Text('Nova câmera'),
        ),
      ],
      child: const EmptyPanel(
        icon: Icons.videocam_outlined,
        title: 'Nenhuma câmera cadastrada',
        description:
            'Adicione uma câmera por endereço ou procure dispositivos na rede local.',
      ),
    );
  }
}
