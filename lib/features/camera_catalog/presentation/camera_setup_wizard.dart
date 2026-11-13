import 'package:flutter/material.dart';

import '../domain/camera_field_validation.dart';

class CameraSetupWizard extends StatefulWidget {
  const CameraSetupWizard({
    required this.name,
    required this.host,
    required this.username,
    required this.password,
    required this.validate,
    required this.onTest,
    required this.onSave,
    required this.onAdvanced,
    required this.onTemplate,
    required this.busy,
    required this.tested,
    required this.editing,
    super.key,
  });
  final TextEditingController name, host, username, password;
  final bool Function() validate;
  final VoidCallback onTest, onSave, onAdvanced;
  final void Function(String) onTemplate;
  final bool busy, tested, editing;

  @override
  State<CameraSetupWizard> createState() => _CameraSetupWizardState();
}

class _CameraSetupWizardState extends State<CameraSetupWizard> {
  int _step = 0;
  bool _obscure = true;
  String _template = 'existing';

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Passo ${_step + 1} de 3',
        style: Theme.of(context).textTheme.labelLarge,
      ),
      const SizedBox(height: 8),
      LinearProgressIndicator(value: (_step + 1) / 3),
      const SizedBox(height: 20),
      if (_step == 0) ...[
        Text(
          'Onde está a câmera?',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: widget.name,
          maxLength: 80,
          decoration: const InputDecoration(
            labelText: 'Nome da câmera',
            hintText: 'Ex.: Garagem',
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: widget.host,
          keyboardType: TextInputType.url,
          validator: (v) => CameraFieldValidation.hostError(v ?? ''),
          decoration: const InputDecoration(
            labelText: 'Endereço da câmera (IP)',
            hintText: '192.168.1.50',
          ),
        ),
        const SizedBox(height: 12),
        const Text('Conecte este aparelho à mesma rede da câmera.'),
      ],
      if (_step == 1) ...[
        Text('Como acessar?', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        TextFormField(
          controller: widget.username,
          maxLength: 128,
          decoration: const InputDecoration(
            labelText: 'Usuário',
            helperText: 'Em branco: usa o acesso já configurado.',
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: widget.password,
          obscureText: _obscure,
          maxLength: 1024,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: 'Senha',
            suffixIcon: IconButton(
              tooltip: _obscure ? 'Mostrar senha' : 'Ocultar senha',
              onPressed: () => setState(() => _obscure = !_obscure),
              icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
            ),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _template,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Marca / família do modelo',
          ),
          items: const [
            DropdownMenuItem(
              value: 'existing',
              child: Text('Manter configuração atual'),
            ),
            DropdownMenuItem(
              value: 'hikvision',
              child: Text('Hikvision / compatível'),
            ),
            DropdownMenuItem(
              value: 'dahua',
              child: Text('Dahua / Intelbras compatível'),
            ),
          ],
          onChanged: widget.busy
              ? null
              : (value) {
                  if (value == null) return;
                  setState(() => _template = value);
                  widget.onTemplate(value);
                },
        ),
        const SizedBox(height: 8),
        const Text(
          'O caminho de vídeo varia por modelo. Se a imagem não abrir, use os ajustes avançados.',
        ),
      ],
      if (_step == 2) ...[
        Text('Confira a imagem', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Text(
          widget.tested
              ? 'Imagem confirmada. Sua câmera está pronta.'
              : 'Teste a conexão antes de salvar. Você também pode salvar agora e conectar depois.',
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: widget.busy ? null : widget.onTest,
          icon: const Icon(Icons.play_circle_outline),
          label: const Text('Testar conexão'),
        ),
      ],
      const SizedBox(height: 20),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.end,
        children: [
          if (_step > 0)
            TextButton(
              onPressed: widget.busy ? null : () => setState(() => _step--),
              child: const Text('Voltar'),
            ),
          if (_step < 2)
            FilledButton.icon(
              onPressed: widget.busy
                  ? null
                  : () {
                      if (widget.validate()) setState(() => _step++);
                    },
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Continuar'),
            )
          else
            FilledButton.icon(
              onPressed: widget.busy ? null : widget.onSave,
              icon: const Icon(Icons.save_outlined),
              label: Text(
                widget.tested ? 'Salvar câmera' : 'Salvar e conectar depois',
              ),
            ),
        ],
      ),
      const SizedBox(height: 8),
      TextButton.icon(
        onPressed: widget.busy ? null : widget.onAdvanced,
        icon: const Icon(Icons.tune),
        label: const Text('Abrir ajustes avançados'),
      ),
    ],
  );
}
