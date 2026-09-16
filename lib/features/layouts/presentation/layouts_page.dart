import 'package:flutter/material.dart';

import '../../../app/state/app_store.dart';
import '../../../shared/design_system/page_frame.dart';
import '../domain/layout_preset.dart';

class LayoutsPage extends StatelessWidget {
  const LayoutsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final layout = store.activeLayout;
    return PageFrame(
      title: 'Layouts',
      subtitle: 'Escolha a grade e associe câmeras a cada posição.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final preset in LayoutPreset.all)
                    ChoiceChip(
                      label: Text(preset.name),
                      selected: preset.id == layout.id,
                      onSelected: (_) => store.setLayout(preset.id),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Câmeras na grade',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          if (store.cameras.isEmpty)
            const EmptyPanel(
              icon: Icons.videocam_outlined,
              title: 'Adicione câmeras primeiro',
              description:
                  'Depois você poderá selecionar uma câmera para cada posição da grade.',
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 900 ? 2 : 1;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: layout.cameraCount,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 8,
                    mainAxisExtent: 76,
                  ),
                  itemBuilder: (context, index) {
                    final selected = index < store.config.slotCameraIds.length
                        ? store.config.slotCameraIds[index]
                        : null;
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 15,
                              child: Text('${index + 1}'),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String?>(
                                  isExpanded: true,
                                  value: selected,
                                  hint: const Text('Posição vazia'),
                                  items: [
                                    const DropdownMenuItem<String?>(
                                      value: null,
                                      child: Text('Não atribuir câmera'),
                                    ),
                                    for (final camera in store.cameras)
                                      DropdownMenuItem(
                                        value: camera.id,
                                        child: Text(
                                          camera.name,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                  ],
                                  onChanged: (id) => store.setSlot(index, id),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: store.clearSlots,
              icon: const Icon(Icons.clear_all),
              label: const Text('Limpar grade'),
            ),
          ),
        ],
      ),
    );
  }
}
