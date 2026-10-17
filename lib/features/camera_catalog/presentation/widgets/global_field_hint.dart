import 'package:flutter/material.dart';

class GlobalFieldHint extends StatelessWidget {
  const GlobalFieldHint({
    required this.controller,
    required this.globalValue,
    this.trim = true,
    this.isInherited,
    super.key,
  });

  final TextEditingController controller;
  final String globalValue;
  final bool trim;
  final bool? isInherited;

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          final inherited =
              isInherited ?? (trim ? value.text.trim() : value.text).isEmpty;
          return Text(
            inherited
                ? 'Usando global: $globalValue'
                : 'Valor específico desta câmera',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          );
        },
      );
}
