import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:rtsp_hub/main.dart';
import 'package:rtsp_hub/app/data/app_configuration.dart';
import 'package:rtsp_hub/app/state/app_store.dart';
import 'package:rtsp_hub/features/camera_catalog/domain/camera_device.dart';
import 'package:rtsp_hub/features/layouts/domain/saved_monitor_profile.dart';
import 'package:rtsp_hub/features/camera_catalog/presentation/widgets/camera_preview_card.dart';
import 'package:rtsp_hub/shared/infrastructure/secure_store/credential_store.dart';
import 'package:rtsp_hub/shared/infrastructure/storage/config_repository.dart';

void main() {
  testWidgets('inicio mostra miniaturas e aplica perfil sem abrir players', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final cameras = List.generate(
      4,
      (index) => CameraDevice(
        id: 'cam-$index',
        name: 'Câmera ${index + 1}',
        host: '192.168.1.${index + 10}',
        mainPath: '/main',
      ),
    );
    await tester.pumpWidget(
      _app(
        configuration: AppConfiguration(
          startupSection: 'dashboard',
          tutorialCompleted: true,
          cameras: cameras,
          monitorProfiles: const [
            SavedMonitorProfile(
              id: 'single',
              name: 'Somente garagem',
              layoutId: 'SINGLE',
              slotCameraIds: ['cam-1'],
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CameraPreviewCard), findsNWidgets(4));
    expect(find.byType(Video), findsNothing);
    expect(find.text('AO VIVO'), findsNothing);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Somente garagem').last);
    await tester.pumpAndSettle();

    final store = tester.widget<AppScope>(find.byType(AppScope)).notifier!;
    expect(store.config.layoutId, 'SINGLE');
    expect(store.config.slotCameraIds, ['cam-1']);
    expect(find.text('Suas câmeras'), findsOneWidget);
    expect(find.byType(Video), findsNothing);
  });

  testWidgets(
    'ocultar controles preserva a grade e tocar no monitor os restaura',
    (tester) async {
      await tester.pumpWidget(
        _app(
          configuration: const AppConfiguration(
            startupSection: 'monitor',
            tutorialCompleted: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final viewport = find.byKey(const ValueKey('monitorViewport'));
      final originalSize = tester.getSize(viewport);
      await tester.tap(find.byTooltip('Ações do monitor'));
      await tester.pumpAndSettle();
      final originalWidget = tester.widget(viewport);
      await tester.ensureVisible(find.text('Ocultar controles'));
      await tester.tap(find.text('Ocultar controles'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Ações do monitor'), findsNothing);
      expect(tester.getSize(viewport), originalSize);
      expect(identical(tester.widget(viewport), originalWidget), isTrue);
      await tester.tapAt(tester.getCenter(viewport));
      await tester.pump();
      expect(find.byTooltip('Ações do monitor'), findsOneWidget);
      expect(tester.getSize(viewport), originalSize);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('monitor permite diagnostico por toque em celular estreito', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      _app(
        configuration: const AppConfiguration(
          startupSection: 'monitor',
          tutorialCompleted: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ações do monitor'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Diagnósticos das câmeras'));
    await tester.pumpAndSettle();
    expect(find.text('Diagnósticos da sessão'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('abre a tela inicial do RTSP Hub', (tester) async {
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

    expect(find.text('Bem-vindo ao RTSP Hub'), findsOneWidget);
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
    await tester.tap(find.byKey(const ValueKey('sidebar_layouts')));
    await tester.pumpAndSettle();

    expect(find.text('Prévia do monitor'), findsOneWidget);
    expect(
      find.textContaining('Pressione e arraste para trocar posições'),
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

    expect(find.text('Usa a conexão global'), findsOneWidget);
    expect(find.text('Usuário global'), findsNothing);
    expect(find.text('Senha global'), findsNothing);
    expect(find.text('Buscar câmeras'), findsOneWidget);
    expect(find.text('Pesquisar canais de gravadores'), findsOneWidget);
    expect(find.text('Procurar até o canal'), findsNothing);
    await tester.ensureVisible(find.text('Pesquisar canais de gravadores'));
    await tester.tap(find.text('Pesquisar canais de gravadores'));
    await tester.pump();
    expect(find.text('Procurar até o canal'), findsOneWidget);
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
    expect(find.byTooltip('Ver vídeo de Entrada principal'), findsOneWidget);
    await tester.enterText(find.byType(EditableText).last, 'garagem');
    await tester.pumpAndSettle();
    expect(find.text('Entrada principal'), findsNothing);
    expect(
      find.text('Nenhuma câmera encontrada. Tente outro nome ou IP.'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(EditableText).last, '192.168.1.5');
    await tester.pumpAndSettle();
    expect(find.text('Entrada principal'), findsOneWidget);

    await tester.tap(find.text('Entrada principal'));
    await tester.pumpAndSettle();
    expect(find.text('Entrada principal'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'atalho de acesso rápido na tela inicial abre o monitor com o último perfil',
    (tester) async {
      const profile = SavedMonitorProfile(
        id: 'p1',
        name: 'Entrada e Garagem',
        layoutId: 'GRID_2H',
        slotCameraIds: [null, null],
      );
      final config = const AppConfiguration(
        startupSection: 'dashboard',
        tutorialCompleted: true,
        monitorProfiles: [profile],
        lastProfileId: 'p1',
      );
      await tester.pumpWidget(_app(configuration: config));
      await tester.pumpAndSettle();

      final quickStart = find
          .textContaining('Acesso rápido · Entrada e Garagem')
          .first;
      expect(quickStart, findsOneWidget);
      await tester.tap(quickStart);
      await tester.pumpAndSettle();

      expect(find.text('MONITOR  ·  0 CÂMERAS'), findsOneWidget);
    },
  );

  testWidgets('acesso rápido com nome longo cabe em celular estreito', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const profile = SavedMonitorProfile(
      id: 'p1',
      name: 'Monitor da portaria principal e acesso lateral da garagem à noite',
      layoutId: 'GRID_4',
      slotCameraIds: [null, null, null, null],
    );
    await tester.pumpWidget(
      _app(
        configuration: const AppConfiguration(
          startupSection: 'dashboard',
          tutorialCompleted: true,
          monitorProfiles: [profile],
          lastProfileId: 'p1',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Acesso rápido'), findsWidgets);
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
