import 'package:flutter/material.dart';

enum StreamChoice { both, main, sub }

class DetectedChannel {
  const DetectedChannel({
    required this.host,
    required this.port,
    required this.number,
    required this.username,
    required this.password,
    required this.mainPath,
    required this.mainQuality,
    required this.subPath,
    required this.subQuality,
    required this.verified,
  });

  final String host;
  final int port;
  final int number;
  final String username;
  final String password;
  final String mainPath;
  final String mainQuality;
  final String? subPath;
  final String? subQuality;
  final bool verified;
  String get key => '$host:$port:$number';
}

class DiscoveredHostGroup extends StatelessWidget {
  const DiscoveredHostGroup({
    required this.host,
    required this.displayName,
    required this.channels,
    required this.selected,
    required this.choiceFor,
    required this.onChoice,
    required this.onChanged,
    super.key,
  });

  final String host;
  final String displayName;
  final List<DetectedChannel> channels;
  final Set<String> selected;
  final StreamChoice Function(DetectedChannel channel) choiceFor;
  final void Function(DetectedChannel channel, StreamChoice choice) onChoice;
  final void Function(DetectedChannel channel, bool selected) onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                displayName,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            for (final channel in channels) ...[
              CheckboxListTile(
                value: selected.contains(channel.key),
                onChanged: (value) => onChanged(channel, value ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  'Câmera ${channel.number} · principal ${channel.mainQuality}',
                ),
                subtitle: Text(
                  '${channel.verified ? 'Vídeo confirmado' : 'Informado por ONVIF · vídeo ainda não testado'}\nPrincipal: ${channel.mainPath}${channel.subPath == null ? '' : '\nSecundário: ${channel.subPath} · ${channel.subQuality}'}',
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (channel.subPath != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(56, 0, 16, 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedButton<StreamChoice>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: StreamChoice.both,
                          label: Text('Principal + sub'),
                        ),
                        ButtonSegment(
                          value: StreamChoice.main,
                          label: Text('Só principal'),
                        ),
                        ButtonSegment(
                          value: StreamChoice.sub,
                          label: Text('Só subfluxo'),
                        ),
                      ],
                      selected: {choiceFor(channel)},
                      onSelectionChanged: (value) =>
                          onChoice(channel, value.first),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
