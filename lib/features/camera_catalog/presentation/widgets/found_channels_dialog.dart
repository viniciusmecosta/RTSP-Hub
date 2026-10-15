import 'package:flutter/material.dart';

import '../../domain/found_channel.dart';

class FoundChannelsDialog extends StatelessWidget {
  const FoundChannelsDialog({required this.channels, super.key});

  final List<FoundChannel> channels;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Canais encontrados'),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: MediaQuery.sizeOf(context).height * 0.72,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final channel in channels)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Canal ${channel.number}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Principal: ${channel.mainQuality.isEmpty ? channel.mainPath : channel.mainQuality}',
                      ),
                      if (channel.subPath != null)
                        Text(
                          'Subfluxo: ${channel.subQuality?.isNotEmpty == true ? channel.subQuality : channel.subPath}',
                        ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.tonal(
                            onPressed: () =>
                                Navigator.pop(context, (channel, false)),
                            child: Text(
                              channel.subPath == null
                                  ? 'Usar'
                                  : 'Usar principal + sub',
                            ),
                          ),
                          if (channel.subPath != null)
                            OutlinedButton(
                              onPressed: () =>
                                  Navigator.pop(context, (channel, true)),
                              child: const Text('Usar só subfluxo'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}
