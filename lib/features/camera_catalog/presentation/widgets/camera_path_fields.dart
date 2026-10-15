import 'package:flutter/material.dart';

import '../../domain/camera_field_validation.dart';

class CameraPathFields extends StatelessWidget {
  const CameraPathFields({
    required this.mainPathController,
    required this.subPathController,
    required this.defaultPath,
    required this.defaultSubPath,
    required this.savedPaths,
    required this.onAddSavedPath,
    required this.onSelectSavedPath,
    required this.onRemoveSavedPath,
    required this.searchRecorderChannels,
    required this.onToggleSearchRecorderChannels,
    required this.isProbingOrTesting,
    super.key,
  });

  final TextEditingController mainPathController;
  final TextEditingController subPathController;
  final String defaultPath;
  final String defaultSubPath;
  final List<String> savedPaths;
  final void Function(String path) onAddSavedPath;
  final void Function(String path) onSelectSavedPath;
  final void Function(String path) onRemoveSavedPath;
  final bool searchRecorderChannels;
  final ValueChanged<bool>? onToggleSearchRecorderChannels;
  final bool isProbingOrTesting;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: mainPathController,
          decoration: InputDecoration(
            labelText: 'Canal / caminho específico',
            hintText: defaultPath,
            helperText: savedPaths.isEmpty
                ? 'Vazio usa o canal padrão'
                : 'Selecione na lista suspensa/opções ou informe o canal',
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (mainPathController.text.trim().isNotEmpty &&
                    !savedPaths.contains(mainPathController.text.trim()))
                  IconButton(
                    icon: const Icon(Icons.bookmark_add_outlined),
                    tooltip: 'Salvar canal na lista',
                    onPressed: () {
                      final error = CameraFieldValidation.pathError(
                        mainPathController.text.trim(),
                      );
                      if (error == null) {
                        onAddSavedPath(mainPathController.text.trim());
                      }
                    },
                  ),
                if (savedPaths.isNotEmpty)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.arrow_drop_down),
                    tooltip: 'Canais salvos',
                    onSelected: onSelectSavedPath,
                    itemBuilder: (context) => savedPaths
                        .map(
                          (path) => PopupMenuItem<String>(
                            value: path,
                            child: Row(
                              children: [
                                Icon(
                                  path == mainPathController.text.trim()
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  size: 16,
                                  color: path == mainPathController.text.trim()
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    path,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
              ],
            ),
          ),
          validator: (value) => (value ?? '').trim().isEmpty
              ? null
              : CameraFieldValidation.pathError(value ?? ''),
        ),
        if (savedPaths.isNotEmpty) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ...savedPaths.map((path) {
                  final isSelected = path == mainPathController.text.trim();
                  return InputChip(
                    selected: isSelected,
                    label: Text(path, style: const TextStyle(fontSize: 11)),
                    onSelected: (_) => onSelectSavedPath(path),
                    onDeleted: savedPaths.length > 1
                        ? () => onRemoveSavedPath(path)
                        : null,
                    deleteButtonTooltipMessage: 'Remover canal salvo',
                  );
                }),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        TextFormField(
          controller: subPathController,
          decoration: InputDecoration(
            labelText: 'Subfluxo específico (opcional)',
            hintText: defaultSubPath,
            helperText: 'Vazio usa o subfluxo global',
          ),
          validator: (value) =>
              CameraFieldValidation.pathError(value ?? '', optional: true),
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Pesquisar canais de gravador'),
          subtitle: const Text(
            'Se ONVIF não responder, teste até 16 canais RTSP. Para câmera IP, deixe desligado.',
          ),
          value: searchRecorderChannels,
          onChanged: isProbingOrTesting
              ? null
              : onToggleSearchRecorderChannels,
        ),
      ],
    );
  }
}
