import 'package:flutter/material.dart';

import '../../../shared/design_system/page_frame.dart';

class LayoutsPage extends StatelessWidget {
  const LayoutsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'Layouts',
      subtitle: 'Escolha quantas câmeras aparecem e organize cada posição.',
      child: const EmptyPanel(
        icon: Icons.grid_view_rounded,
        title: 'Prepare sua grade',
        description:
            'Escolha um layout de até 4 posições para iniciar. Grades maiores poderão ser percorridas por páginas.',
      ),
    );
  }
}
