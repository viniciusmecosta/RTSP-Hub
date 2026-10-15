import 'package:flutter/material.dart';

import '../../../../app/state/app_store.dart';
import '../../domain/camera_device.dart';
import '../../domain/camera_field_validation.dart';

class CameraNetworkFields extends StatelessWidget {
  const CameraNetworkFields({
    required this.nameController,
    required this.hostController,
    required this.portController,
    required this.mainPathController,
    required this.store,
    required this.editingCamera,
    required this.onPortChanged,
    required this.onPortReset,
    super.key,
  });

  final TextEditingController nameController;
  final TextEditingController hostController;
  final TextEditingController portController;
  final TextEditingController mainPathController;
  final AppStore store;
  final CameraDevice? editingCamera;
  final ValueChanged<String> onPortChanged;
  final VoidCallback onPortReset;

  @override
  Widget build(BuildContext context) {
    final defaultPort = store.config.defaultPort;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Nome',
            hintText: 'Ex.: Entrada principal',
          ),
          maxLength: 80,
          buildCounter:
              (_, {required currentLength, required isFocused, maxLength}) =>
                  null,
          validator: (value) => (value?.trim().length ?? 0) > 80
              ? 'Use até 80 caracteres.'
              : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: hostController,
          decoration: const InputDecoration(
            labelText: 'Endereço IP ou host',
            hintText: '192.168.1.50',
          ),
          keyboardType: TextInputType.url,
          validator: (value) {
            final host = value?.trim() ?? '';
            final error = CameraFieldValidation.hostError(host);
            if (error != null) return error;
            final port =
                int.tryParse(portController.text.trim()) ?? defaultPort;
            final enteredPath = mainPathController.text.trim().isEmpty
                ? store.config.defaultPath
                : mainPathController.text.trim();
            final path = enteredPath.startsWith('/')
                ? enteredPath
                : '/$enteredPath';
            final duplicate = store.cameras.any(
              (camera) =>
                  camera.id != editingCamera?.id &&
                  camera.host.toLowerCase() == host.toLowerCase() &&
                  camera.effectivePort(defaultPort) == port &&
                  store.resolveCamera(camera).mainPath == path,
            );
            return duplicate
                ? 'Esse endereço, porta e caminho já estão cadastrados.'
                : null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: portController,
          onChanged: onPortChanged,
          decoration: InputDecoration(
            labelText: 'Porta',
            hintText: '$defaultPort',
            helperText: 'Padrão: $defaultPort',
            suffixIcon: IconButton(
              tooltip: 'Usar porta global',
              icon: const Icon(Icons.restart_alt),
              onPressed: onPortReset,
            ),
          ),
          keyboardType: TextInputType.number,
          buildCounter:
              (_, {required currentLength, required isFocused, maxLength}) =>
                  null,
          validator: (value) => CameraFieldValidation.portError(value ?? ''),
        ),
      ],
    );
  }
}
