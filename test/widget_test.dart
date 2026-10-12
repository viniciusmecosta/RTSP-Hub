import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:rtsp_view/main.dart';
import 'package:rtsp_view/app/data/app_configuration.dart';
import 'package:rtsp_view/app/state/app_store.dart';
import 'package:rtsp_view/features/camera_catalog/domain/camera_device.dart';
import 'package:rtsp_view/shared/infrastructure/secure_store/credential_store.dart';
import 'package:rtsp_view/shared/infrastructure/storage/config_repository.dart';

void main() {
  testWidgets('abre a tela inicial do RTSP View', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Entendi'));
    await tester.pumpAndSettle();

    expect(find.text('Adicionar câmera'), findsWidgets);
  });

  testWidgets('atalho F3 abre diagnósticos e F2 volta para câmeras', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Entendi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Monitor'));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.f3);
    await tester.pumpAndSettle();
    expect(find.text('Diagnósticos da sessão'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.f2);
    await tester.pumpAndSettle();
    expect(find.text('Adicionar câmera'), findsWidgets);
  });

  testWidgets('primeira execução apresenta guia para cadastro', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Bem-vindo ao RTSP View'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editor mostra uma prévia estática do monitor', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Entendi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Layouts'));
    await tester.pumpAndSettle();

    expect(find.text('Prévia do monitor'), findsOneWidget);
    expect(
      find.text('Visualização aproximada da grade. Não inicia transmissões.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('pesquisa de rede fica dentro da página de câmeras', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Entendi'));
    await tester.pumpAndSettle();

    expect(find.text('Encontrar câmeras na rede'), findsOneWidget);
    expect(find.text('Achador de canais'), findsNothing);
    await tester.tap(find.text('Encontrar câmeras na rede'));
    await tester.pumpAndSettle();

    expect(find.text('Usuário global'), findsOneWidget);
    expect(find.text('Senha global'), findsOneWidget);
    expect(find.text('Buscar câmeras'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('seleção de câmera mostra detalhes e atualiza a posição', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const camera = CameraDevice(
      id: 'entrance',
      name: 'Entrada principal',
      host: '192.168.1.5',
      port: 554,
      mainPath: '/1/1?profile=main',
    );
    await tester.pumpWidget(
      _app(
        configuration: const AppConfiguration(
          cameras: [camera],
          startupSection: 'layouts',
          tutorialCompleted: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Selecionar câmera').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Selecionar câmera').first);
    await tester.pumpAndSettle();
    expect(find.text('Câmera da posição 1'), findsOneWidget);
    expect(find.text('Entrada principal'), findsOneWidget);
    expect(find.textContaining('192.168.1.5:554'), findsOneWidget);

    await tester.tap(find.text('Entrada principal'));
    await tester.pumpAndSettle();
    expect(find.text('Entrada principal'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

MyApp _app({AppConfiguration? configuration}) => MyApp(
  store: AppStore(
    repository: _TestConfigRepository(configuration),
    credentials: _TestCredentialStore(),
  ),
);

class _TestConfigRepository extends ConfigRepository {
  _TestConfigRepository([AppConfiguration? configuration])
    : configuration = configuration ?? const AppConfiguration();

  AppConfiguration configuration;

  @override
  Future<AppConfiguration> load() async => configuration;

  @override
  Future<void> save(AppConfiguration config) async {
    configuration = config;
  }
}

class _TestCredentialStore extends CredentialStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String cameraId) async => values[cameraId];

  @override
  Future<void> write(String cameraId, String password) async {
    values[cameraId] = password;
  }

  @override
  Future<void> delete(String cameraId) async {
    values.remove(cameraId);
  }
}
