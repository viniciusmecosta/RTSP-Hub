import 'dart:async';
import 'package:flutter/material.dart';
import '../../../app/state/app_store.dart';
import '../../../shared/design_system/page_frame.dart';
import '../../camera_catalog/domain/camera_field_validation.dart';

class GlobalConnectionPage extends StatelessWidget {
  const GlobalConnectionPage({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(
    context,
  ).push<void>(MaterialPageRoute(builder: (_) => const GlobalConnectionPage()));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Conexão global')),
    body: const PageFrame(
      title: 'Configure uma vez',
      subtitle:
          'Os mesmos padrões para cadastrar, encontrar e visualizar suas câmeras.',
      child: GlobalConnectionCard(),
    ),
  );
}

class GlobalConnectionShortcut extends StatelessWidget {
  const GlobalConnectionShortcut({super.key});

  @override
  Widget build(BuildContext context) {
    final config = AppScope.of(context).config;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(18),
        leading: Icon(
          Icons.settings_ethernet,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: const Text('Conexão global'),
        subtitle: Text(
          'Usuário ${config.defaultUser.isEmpty ? "não definido" : config.defaultUser} · Porta ${config.defaultPort}\nCanais e credenciais padrão para todas as câmeras',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => GlobalConnectionPage.open(context),
      ),
    );
  }
}

class GlobalConnectionCard extends StatefulWidget {
  const GlobalConnectionCard({super.key});

  @override
  State<GlobalConnectionCard> createState() => GlobalConnectionCardState();
}

class GlobalConnectionCardState extends State<GlobalConnectionCard> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _port = TextEditingController();
  final _channel = TextEditingController();
  final _subChannel = TextEditingController();
  bool _loading = true;
  bool _loaded = false;
  bool _saving = false;
  bool _obscure = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    final store = AppScope.of(context);
    _username.text = store.config.defaultUser;
    _port.text = '${store.config.defaultPort}';
    _channel.text = store.config.defaultPath;
    _subChannel.text = store.config.defaultSubPath;
    unawaited(
      store.networkDiscoveryPassword().then((password) {
        if (!mounted) return;
        setState(() {
          _password.text = password ?? '';
          _loading = false;
        });
      }),
    );
  }

  @override
  void dispose() {
    for (final controller in [
      _username,
      _password,
      _port,
      _channel,
      _subChannel,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final store = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    final path = _channel.text.trim();
    final saved = await store.saveGlobalConnection(
      username: _username.text,
      password: _password.text,
      port: _port.text,
      mainPath: path,
      subPath: _subChannel.text,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? 'Conexão global salva. Campos herdados das câmeras foram atualizados.'
              : store.message ?? 'Não foi possível salvar a conexão padrão.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fields = <Widget>[
      TextFormField(
        controller: _username,
        decoration: const InputDecoration(labelText: 'Usuário global'),
        validator: (value) =>
            (value?.length ?? 0) > 128 ? 'Use até 128 caracteres.' : null,
      ),
      TextFormField(
        controller: _password,
        obscureText: _obscure,
        autocorrect: false,
        enableSuggestions: false,
        decoration: InputDecoration(
          labelText: 'Senha global',
          suffixIcon: IconButton(
            tooltip: _obscure ? 'Mostrar senha' : 'Ocultar senha',
            onPressed: () => setState(() => _obscure = !_obscure),
            icon: Icon(
              _obscure
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
          ),
        ),
        validator: (value) =>
            (value?.length ?? 0) > 1024 ? 'Use até 1024 caracteres.' : null,
      ),
      TextFormField(
        controller: _port,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Porta padrão'),
        validator: (value) => (value ?? '').trim().isEmpty
            ? 'Informe a porta.'
            : CameraFieldValidation.portError(value ?? ''),
      ),
      TextFormField(
        controller: _channel,
        decoration: const InputDecoration(
          labelText: 'Canal / caminho RTSP global',
          hintText: '/Streaming/Channels/101',
        ),
        validator: (value) => CameraFieldValidation.pathError(value ?? ''),
      ),
      TextFormField(
        controller: _subChannel,
        decoration: const InputDecoration(
          labelText: 'Subfluxo global (opcional)',
          hintText: '/Streaming/Channels/102',
        ),
        validator: (value) =>
            CameraFieldValidation.pathError(value ?? '', optional: true),
      ),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: AbsorbPointer(
          absorbing: _saving || _loading,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Padrões de conexão',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Cada campo específico da câmera tem prioridade. Se estiver vazio, usa o valor global correspondente. A busca de rede também utiliza estes padrões.',
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 640 ? 2 : 1;
                    final width =
                        (constraints.maxWidth - (columns - 1) * 12) / columns;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final field in fields)
                          SizedBox(width: width, child: field),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _saving || _loading ? null : _save,
                    icon: _saving || _loading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      _saving ? 'Salvando…' : 'Salvar conexão global',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
