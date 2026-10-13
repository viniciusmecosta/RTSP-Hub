import 'package:flutter/material.dart';

import '../../../app/state/app_store.dart';
import '../domain/camera_device.dart';
import '../domain/camera_field_validation.dart';

class CloneCameraDialog extends StatefulWidget {
  const CloneCameraDialog({
    required this.camera,
    required this.store,
    super.key,
  });

  final CameraDevice camera;
  final AppStore store;

  static Future<bool?> show(
    BuildContext context, {
    required CameraDevice camera,
    required AppStore store,
  }) => showDialog<bool>(
    context: context,
    builder: (_) => CloneCameraDialog(camera: camera, store: store),
  );

  @override
  State<CloneCameraDialog> createState() => _CloneCameraDialogState();
}

class _CloneCameraDialogState extends State<CloneCameraDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _host;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _host = TextEditingController();
  }

  @override
  void dispose() {
    _host.dispose();
    super.dispose();
  }

  Future<void> _clone() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final success = await widget.store.cloneCamera(
      widget.camera,
      newHost: _host.text.trim(),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (success) {
      Navigator.pop(context, true);
    } else {
      final msg = widget.store.message ?? 'Não foi possível clonar a câmera.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Clonar câmera'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Clonando as configurações de “${widget.camera.name}”. Informe apenas o endereço IP da nova câmera:',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _host,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Endereço IP da nova câmera',
                  hintText: '192.168.1.51',
                ),
                validator: (value) {
                  final error = CameraFieldValidation.hostError(value ?? '');
                  if (error != null) return error;
                  if (value?.trim().toLowerCase() ==
                      widget.camera.host.toLowerCase()) {
                    return 'Informe um IP diferente da câmera original.';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _clone(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _busy ? null : _clone,
          icon: _busy
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.copy_outlined),
          label: const Text('Clonar'),
        ),
      ],
    );
  }
}
