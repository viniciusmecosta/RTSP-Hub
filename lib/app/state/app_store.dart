import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../features/camera_catalog/domain/camera_device.dart';
import '../../features/camera_catalog/domain/camera_field_validation.dart';
import '../../features/layouts/domain/layout_preset.dart';
import '../../features/layouts/domain/saved_monitor_profile.dart';
import '../../shared/infrastructure/secure_store/credential_store.dart';
import '../../shared/infrastructure/storage/config_repository.dart';
import '../data/app_configuration.dart';

class AppStore extends ChangeNotifier {
  static const _networkDiscoveryCredentialId = '__network_discovery__';
  AppStore({ConfigRepository? repository, CredentialStore? credentials})
    : _repository = repository ?? ConfigRepository(),
      _credentials = credentials ?? CredentialStore();

  final ConfigRepository _repository;
  final CredentialStore _credentials;
  final Map<String, String> _passwords = {};
  final ValueNotifier<ThemeMode> themeModeListenable = ValueNotifier(
    ThemeMode.system,
  );
  Future<void> _settingsQueue = Future.value();
  AppConfiguration _config = const AppConfiguration();
  bool _loading = true;
  String? _message;

  AppConfiguration get config => _config;
  List<CameraDevice> get cameras => _config.cameras;
  bool get loading => _loading;
  String? get message => _message;
  ThemeMode get themeMode => switch (_config.themeMode) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
  LayoutPreset get activeLayout => LayoutPreset.byId(_config.layoutId);

  SavedMonitorProfile? get lastSavedProfile {
    final id = _config.lastProfileId;
    if (id != null) {
      final match = _config.monitorProfiles
          .where((profile) => profile.id == id)
          .firstOrNull;
      if (match != null) return match;
    }
    return _config.monitorProfiles.lastOrNull;
  }

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    try {
      _config = await _repository.load();
      themeModeListenable.value = themeMode;
      final validIds = _config.cameras.map((camera) => camera.id).toSet();
      final slots = _config.slotCameraIds
          .map((id) => id != null && validIds.contains(id) ? id : null)
          .toList();
      if (slots.length != activeLayout.cameraCount ||
          !_sameSlots(slots, _config.slotCameraIds)) {
        slots
          ..removeRange(
            activeLayout.cameraCount.clamp(0, slots.length),
            slots.length,
          )
          ..addAll(
            List<String?>.filled(activeLayout.cameraCount - slots.length, null),
          );
        _config = _config.copyWith(slotCameraIds: slots);
      }
      _message = null;
    } on Object {
      _message = 'Não foi possível carregar as configurações salvas.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> saveCamera({
    required String id,
    required String name,
    required String host,
    required String port,
    required String username,
    required String password,
    required String mainPath,
    required String subPath,
    bool useGlobalCredentials = false,
    List<String> savedPaths = const [],
    String selectedPath = '',
  }) async {
    final normalizedHost = host.trim();
    final parsedPort = port.trim().isEmpty
        ? _config.defaultPort
        : int.tryParse(port.trim());
    final path = mainPath.trim().isEmpty
        ? _config.defaultPath
        : mainPath.trim();
    final hostError = CameraFieldValidation.hostError(normalizedHost);
    if (hostError != null) {
      _message = hostError;
      notifyListeners();
      return false;
    }
    final portError = CameraFieldValidation.portError(port);
    if (portError != null || parsedPort == null) {
      _message = portError ?? 'A porta informada não é válida.';
      notifyListeners();
      return false;
    }
    if (name.trim().length > 80 ||
        normalizedHost.length > 253 ||
        username.trim().length > 128 ||
        password.length > 1024) {
      _message = 'Confira o tamanho do nome, usuário, senha e endereço.';
      notifyListeners();
      return false;
    }
    final mainPathError = CameraFieldValidation.pathError(path);
    final subPathError = CameraFieldValidation.pathError(
      subPath,
      optional: true,
    );
    if (mainPathError != null || subPathError != null) {
      _message = mainPathError ?? subPathError!;
      notifyListeners();
      return false;
    }
    if (_config.cameras.any(
      (camera) =>
          camera.id != id &&
          camera.host.toLowerCase() == normalizedHost.toLowerCase() &&
          camera.effectivePort(_config.defaultPort) == parsedPort &&
          camera.mainPath == _normalizePath(path),
    )) {
      _message =
          'Já existe uma câmera cadastrada com o mesmo endereço, porta e caminho.';
      notifyListeners();
      return false;
    }
    final isNewCamera = id.isEmpty;
    // Câmera nova sem usuário e senha herda as credenciais globais.
    if (isNewCamera && username.trim().isEmpty && password.isEmpty) {
      useGlobalCredentials = true;
    }
    final normalizedMain = mainPath.trim().isEmpty
        ? _config.defaultPath
        : _normalizePath(mainPath);
    final normalizedSub = _normalizePath(subPath);
    final allSavedPaths = <String>{
      normalizedMain,
      if (normalizedSub.isNotEmpty) normalizedSub,
      ...savedPaths.map(_normalizePath).where((p) => p.isNotEmpty),
    }.toList();

    final camera = CameraDevice(
      id: isNewCamera ? const Uuid().v4() : id,
      name: name.trim().isEmpty ? normalizedHost : name.trim(),
      host: normalizedHost,
      port: port.trim().isEmpty ? null : parsedPort,
      username: username.trim(),
      useGlobalCredentials: useGlobalCredentials,
      mainPath: normalizedMain,
      subPath: normalizedSub,
      savedPaths: allSavedPaths,
      selectedPath: allSavedPaths.contains(selectedPath) ? selectedPath : '',
    );
    final previousPassword = await _credentials.read(camera.id);
    try {
      if (!useGlobalCredentials && password.isNotEmpty) {
        await _credentials.write(camera.id, password);
        _passwords[camera.id] = password;
      } else if (useGlobalCredentials) {
        await _credentials.delete(camera.id);
        _passwords.remove(camera.id);
      }
      final cameras = [
        ..._config.cameras.where((item) => item.id != camera.id),
        camera,
      ];
      final slots = [..._config.slotCameraIds];
      if (isNewCamera) {
        final emptySlot = slots.indexOf(null);
        if (emptySlot >= 0) slots[emptySlot] = camera.id;
      }
      if (!await _commit(
        _config.copyWith(cameras: cameras, slotCameraIds: slots),
      )) {
        if (useGlobalCredentials || password.isNotEmpty) {
          if (previousPassword == null) {
            await _credentials.delete(camera.id);
            _passwords.remove(camera.id);
          } else {
            await _credentials.write(camera.id, previousPassword);
            _passwords[camera.id] = previousPassword;
          }
        }
        return false;
      }
      _message = 'Câmera salva neste dispositivo.';
      return true;
    } on Object {
      if (useGlobalCredentials || password.isNotEmpty) {
        try {
          if (previousPassword == null) {
            await _credentials.delete(camera.id);
            _passwords.remove(camera.id);
          } else {
            await _credentials.write(camera.id, previousPassword);
            _passwords[camera.id] = previousPassword;
          }
        } on Object {
          _message = 'Falha ao salvar. O cofre não pôde ser restaurado.';
          notifyListeners();
          return false;
        }
      }
      _message = 'Não foi possível salvar. Verifique o acesso ao cofre seguro.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> cloneCamera(
    CameraDevice source, {
    required String newHost,
    String? newName,
  }) async {
    final password = source.useGlobalCredentials
        ? ''
        : await passwordFor(source) ?? '';
    final name = (newName != null && newName.trim().isNotEmpty)
        ? newName.trim()
        : '${source.name} (cópia)';
    return saveCamera(
      id: '',
      name: name,
      host: newHost.trim(),
      port: source.port == null ? '' : '${source.port}',
      username: source.username,
      password: password,
      mainPath: source.mainPath,
      subPath: source.subPath,
      useGlobalCredentials: source.useGlobalCredentials,
      savedPaths: source.savedPaths,
      selectedPath: source.selectedPath,
    );
  }

  Future<bool> switchCameraChannel(String cameraId, String newPath) async {
    final normalized = _normalizePath(newPath);
    final camera = _config.cameras
        .where((item) => item.id == cameraId)
        .firstOrNull;
    if (camera == null ||
        CameraFieldValidation.pathError(normalized) != null ||
        !camera.savedPaths.contains(normalized)) {
      _message = 'Escolha um canal salvo para esta câmera.';
      notifyListeners();
      return false;
    }
    final cameras = _config.cameras.map((c) {
      if (c.id != cameraId) return c;
      return c.copyWith(selectedPath: normalized);
    }).toList();
    return _commit(_config.copyWith(cameras: cameras));
  }

  Future<void> removeCamera(String id) async {
    final cameras = _config.cameras.where((camera) => camera.id != id).toList();
    final slots = _config.slotCameraIds
        .map((slot) => slot == id ? null : slot)
        .toList();
    if (!await _commit(
      _config.copyWith(cameras: cameras, slotCameraIds: slots),
    )) {
      return;
    }
    try {
      await _credentials.delete(id);
      _passwords.remove(id);
      _message = null;
    } on Object {
      _message =
          'Câmera removida. Não foi possível apagar uma credencial antiga do cofre.';
    }
    notifyListeners();
  }

  Future<int> addDiscoveredCameras(List<CameraDevice> discovered) async {
    final cameras = [..._config.cameras];
    final slots = [..._config.slotCameraIds];
    final known = cameras
        .map(
          (camera) =>
              '${camera.host.toLowerCase()}:${camera.effectivePort(_config.defaultPort)}:${camera.mainPath}',
        )
        .toSet();
    var added = 0;
    for (final candidate in discovered) {
      final host = candidate.host.trim();
      final path = _normalizePath(candidate.mainPath);
      final subPath = _normalizePath(candidate.subPath);
      final port = candidate.effectivePort(_config.defaultPort);
      if (CameraFieldValidation.hostError(host) != null ||
          CameraFieldValidation.portError('$port') != null ||
          CameraFieldValidation.pathError(path) != null ||
          CameraFieldValidation.pathError(subPath, optional: true) != null ||
          candidate.name.trim().length > 80 ||
          candidate.username.trim().length > 128) {
        continue;
      }
      final key = '${host.toLowerCase()}:$port:$path';
      if (!known.add(key)) continue;
      final camera = CameraDevice(
        id: const Uuid().v4(),
        name: candidate.name.trim().isEmpty ? host : candidate.name.trim(),
        host: host,
        port: candidate.port,
        username: candidate.username.trim(),
        mainPath: path,
        subPath: subPath,
        useGlobalCredentials: true,
        savedPaths: candidate.savedPaths.isNotEmpty
            ? candidate.savedPaths
            : [path, if (subPath.isNotEmpty) subPath],
      );
      cameras.add(camera);
      final emptySlot = slots.indexOf(null);
      if (emptySlot >= 0) slots[emptySlot] = camera.id;
      added++;
    }
    if (added == 0) return 0;
    final saved = await _commit(
      _config.copyWith(cameras: cameras, slotCameraIds: slots),
    );
    return saved ? added : 0;
  }

  Future<String?> passwordFor(CameraDevice camera) async {
    if (camera.useGlobalCredentials) return networkDiscoveryPassword();
    final memory = _passwords[camera.id];
    if (memory != null) return memory;
    try {
      final password = await _credentials.read(camera.id);
      if (password != null) _passwords[camera.id] = password;
      return password;
    } on Object {
      _message =
          'O cofre está indisponível. Desbloqueie o armazenamento seguro e tente novamente.';
      notifyListeners();
      return null;
    }
  }

  Future<String?> networkDiscoveryPassword() async {
    final memory = _passwords[_networkDiscoveryCredentialId];
    if (memory != null) return memory;
    try {
      final password = await _credentials.read(_networkDiscoveryCredentialId);
      if (password != null) {
        _passwords[_networkDiscoveryCredentialId] = password;
      }
      return password;
    } on Object {
      _message = 'O cofre seguro está indisponível neste dispositivo.';
      notifyListeners();
      return null;
    }
  }

  Future<bool> saveNetworkDiscoveryCredentials({
    required String username,
    required String password,
  }) async {
    try {
      final previousPassword = await _credentials.read(
        _networkDiscoveryCredentialId,
      );
      if (password.isEmpty) {
        await _credentials.delete(_networkDiscoveryCredentialId);
        _passwords.remove(_networkDiscoveryCredentialId);
      } else {
        await _credentials.write(_networkDiscoveryCredentialId, password);
        _passwords[_networkDiscoveryCredentialId] = password;
      }
      final saved = await _commit(
        _config.copyWith(defaultUser: username.trim()),
      );
      if (!saved) {
        if (previousPassword == null) {
          await _credentials.delete(_networkDiscoveryCredentialId);
          _passwords.remove(_networkDiscoveryCredentialId);
        } else {
          await _credentials.write(
            _networkDiscoveryCredentialId,
            previousPassword,
          );
          _passwords[_networkDiscoveryCredentialId] = previousPassword;
        }
      }
      return saved;
    } on Object {
      _message = 'Não foi possível salvar as credenciais globais no cofre.';
      notifyListeners();
      return false;
    }
  }

  Future<void> setLayout(String layoutId) async {
    final previous = _config.slotCameraIds;
    final count = LayoutPreset.byId(layoutId).cameraCount;
    final slots = List<String?>.generate(
      count,
      (index) => index < previous.length ? previous[index] : null,
    );
    await _commit(_config.copyWith(layoutId: layoutId, slotCameraIds: slots));
  }

  Future<void> setSlot(int index, String? cameraId) async {
    final slots = [..._config.slotCameraIds];
    if (index < 0 || index >= slots.length) return;
    for (var i = 0; i < slots.length; i++) {
      if (slots[i] == cameraId && cameraId != null) slots[i] = null;
    }
    slots[index] = cameraId;
    await _commit(_config.copyWith(slotCameraIds: slots));
  }

  Future<void> clearSlots() async {
    await _commit(
      _config.copyWith(
        slotCameraIds: List<String?>.filled(activeLayout.cameraCount, null),
      ),
    );
  }

  Future<bool> saveMonitorProfile({
    String? id,
    required String name,
    String? startupSection,
  }) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty || normalizedName.length > 60) {
      _message = 'O nome do perfil deve ter entre 1 e 60 caracteres.';
      notifyListeners();
      return false;
    }
    if (_config.monitorProfiles.any(
      (profile) =>
          profile.id != id &&
          profile.name.toLowerCase() == normalizedName.toLowerCase(),
    )) {
      _message = 'Já existe um perfil com esse nome.';
      notifyListeners();
      return false;
    }
    if (id == null && _config.monitorProfiles.length >= 20) {
      _message = 'O limite de 20 perfis salvos foi atingido.';
      notifyListeners();
      return false;
    }
    final profile = SavedMonitorProfile(
      id: id ?? const Uuid().v4(),
      name: normalizedName,
      layoutId: _config.layoutId,
      slotCameraIds: List.unmodifiable(_config.slotCameraIds),
      startupSection: startupSection ?? _config.startupSection,
    );
    final profiles = [
      ..._config.monitorProfiles.where((item) => item.id != profile.id),
      profile,
    ];
    return _commit(
      _config.copyWith(monitorProfiles: profiles, lastProfileId: profile.id),
    );
  }

  Future<void> applyMonitorProfile(String id) async {
    final profile = _config.monitorProfiles
        .where((item) => item.id == id)
        .firstOrNull;
    if (profile == null) return;
    final layout = LayoutPreset.byId(profile.layoutId);
    final validIds = _config.cameras.map((camera) => camera.id).toSet();
    final slots = List<String?>.generate(
      layout.cameraCount,
      (index) => index < profile.slotCameraIds.length
          ? switch (profile.slotCameraIds[index]) {
              final cameraId? when validIds.contains(cameraId) => cameraId,
              _ => null,
            }
          : null,
    );
    await _commit(
      _config.copyWith(
        layoutId: layout.id,
        slotCameraIds: slots,
        startupSection: profile.startupSection,
        lastProfileId: profile.id,
      ),
    );
  }

  Future<void> removeMonitorProfile(String id) async {
    final profiles = _config.monitorProfiles
        .where((profile) => profile.id != id)
        .toList(growable: false);
    final clearLast = _config.lastProfileId == id;
    await _commit(
      _config.copyWith(
        monitorProfiles: profiles,
        clearLastProfileId: clearLast,
      ),
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == themeMode) return;
    await _commit(
      _config.copyWith(
        themeMode: switch (mode) {
          ThemeMode.light => 'light',
          ThemeMode.dark => 'dark',
          ThemeMode.system => 'system',
        },
      ),
    );
  }

  Future<void> updateSettings({
    int? defaultPort,
    String? defaultUser,
    String? defaultPath,
    int? bufferMs,
    String? resourceMode,
    bool? autoFullscreen,
    String? startupSection,
    bool? tutorialCompleted,
    String? lastSection,
    int? lastMonitorPage,
  }) async {
    final operation = _settingsQueue.then((_) {
      final current = _config;
      if ((defaultPort == null || defaultPort == current.defaultPort) &&
          (defaultUser == null || defaultUser == current.defaultUser) &&
          (defaultPath == null || defaultPath == current.defaultPath) &&
          (bufferMs == null || bufferMs == current.bufferMs) &&
          (resourceMode == null || resourceMode == current.resourceMode) &&
          (autoFullscreen == null ||
              autoFullscreen == current.autoFullscreen) &&
          (startupSection == null ||
              startupSection == current.startupSection) &&
          (tutorialCompleted == null ||
              tutorialCompleted == current.tutorialCompleted) &&
          (lastSection == null || lastSection == current.lastSection) &&
          (lastMonitorPage == null ||
              lastMonitorPage == current.lastMonitorPage)) {
        return Future<bool>.value(true);
      }
      return _commit(
        current.copyWith(
          defaultPort: defaultPort,
          defaultUser: defaultUser,
          defaultPath: defaultPath,
          bufferMs: bufferMs,
          resourceMode: resourceMode,
          autoFullscreen: autoFullscreen,
          startupSection: startupSection,
          tutorialCompleted: tutorialCompleted,
          lastSection: lastSection,
          lastMonitorPage: lastMonitorPage,
        ),
      );
    });
    _settingsQueue = operation.then<void>((_) {});
    await operation;
  }

  static const profileExportFormat = 'rtsp-view-profiles';

  /// Exporta perfis do monitor com as câmeras que eles usam. Senhas nunca
  /// são incluídas; no outro dispositivo valem as credenciais de lá.
  String exportMonitorProfiles([Set<String>? profileIds]) {
    final profiles = _config.monitorProfiles
        .where(
          (profile) => profileIds == null || profileIds.contains(profile.id),
        )
        .toList(growable: false);
    final cameraIds = {
      for (final profile in profiles)
        ...profile.slotCameraIds.whereType<String>(),
    };
    return const JsonEncoder.withIndent('  ').convert({
      'format': profileExportFormat,
      'version': 1,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'profiles': profiles.map((profile) => profile.toJson()).toList(),
      'cameras': _config.cameras
          .where((camera) => cameraIds.contains(camera.id))
          .map((camera) => camera.toJson())
          .toList(),
    });
  }

  /// Importa perfis exportados, reaproveitando câmeras já cadastradas com o
  /// mesmo endereço, porta e caminho. Retorna quantos perfis foram
  /// adicionados ou `null` se o arquivo for inválido.
  Future<int?> importMonitorProfiles(String source) async {
    final List<SavedMonitorProfile> incomingProfiles;
    final List<CameraDevice> incomingCameras;
    try {
      if (source.length > 5 * 1024 * 1024) throw const FormatException();
      final decoded = jsonDecode(source);
      if (decoded is! Map || decoded['format'] != profileExportFormat) {
        throw const FormatException();
      }
      incomingProfiles = (decoded['profiles'] as List? ?? const [])
          .map(
            (item) => SavedMonitorProfile.fromJson(
              Map<String, Object?>.from(item as Map),
            ),
          )
          .toList(growable: false);
      incomingCameras = (decoded['cameras'] as List? ?? const [])
          .map(
            (item) =>
                CameraDevice.fromJson(Map<String, Object?>.from(item as Map)),
          )
          .toList(growable: false);
    } on Object {
      _message = 'O arquivo não é uma exportação de perfis válida.';
      notifyListeners();
      return null;
    }
    String keyOf(CameraDevice camera) =>
        '${camera.host.toLowerCase()}:${camera.effectivePort(_config.defaultPort)}:${camera.mainPath}';
    final cameras = [..._config.cameras];
    final byKey = {for (final camera in cameras) keyOf(camera): camera.id};
    final idMap = <String, String>{};
    for (final camera in incomingCameras) {
      if (CameraFieldValidation.hostError(camera.host) != null ||
          CameraFieldValidation.pathError(camera.mainPath) != null ||
          CameraFieldValidation.pathError(camera.subPath, optional: true) !=
              null) {
        continue;
      }
      final existing = byKey[keyOf(camera)];
      if (existing != null) {
        idMap[camera.id] = existing;
        continue;
      }
      final created = CameraDevice(
        id: const Uuid().v4(),
        name: camera.name,
        host: camera.host,
        port: camera.port,
        username: camera.username,
        mainPath: camera.mainPath,
        subPath: camera.subPath,
        useGlobalCredentials: true,
        savedPaths: camera.savedPaths,
        selectedPath: camera.selectedPath,
      );
      cameras.add(created);
      byKey[keyOf(created)] = created.id;
      idMap[camera.id] = created.id;
    }
    final profiles = [..._config.monitorProfiles];
    var added = 0;
    for (final profile in incomingProfiles) {
      if (profiles.length >= 20) break;
      var name = profile.name.trim().isEmpty ? 'Perfil' : profile.name.trim();
      final base = name.length > 48 ? name.substring(0, 48) : name;
      var suffix = 1;
      while (profiles.any((p) => p.name.toLowerCase() == name.toLowerCase())) {
        suffix++;
        name = '$base ($suffix)';
      }
      profiles.add(
        SavedMonitorProfile(
          id: const Uuid().v4(),
          name: name,
          layoutId: LayoutPreset.byId(profile.layoutId).id,
          slotCameraIds: [
            for (final id in profile.slotCameraIds)
              id == null ? null : idMap[id],
          ],
          startupSection: profile.startupSection,
        ),
      );
      added++;
    }
    if (added == 0) {
      _message = 'Nenhum perfil novo pôde ser importado.';
      notifyListeners();
      return 0;
    }
    final saved = await _commit(
      _config.copyWith(cameras: cameras, monitorProfiles: profiles),
    );
    return saved ? added : null;
  }

  String exportConfiguration() =>
      const JsonEncoder.withIndent('  ').convert(_config.toJson());

  Future<bool> importConfiguration(String source) async {
    if (source.length > 5 * 1024 * 1024) {
      _message = 'O arquivo de backup excede o limite de 5 MB.';
      notifyListeners();
      return false;
    }
    try {
      final decoded = jsonDecode(source);
      if (decoded is! Map) throw const FormatException();
      final configuration = AppConfiguration.fromJson(
        Map<String, Object?>.from(decoded),
      );
      if (configuration.schemaVersion > _config.schemaVersion) {
        throw const FormatException();
      }
      final cameraIds = <String>{};
      final cameraAddresses = <String>{};
      for (final camera in configuration.cameras) {
        final addressKey =
            '${camera.host.toLowerCase()}:${camera.effectivePort(configuration.defaultPort)}:${camera.mainPath}';
        if (camera.id.isEmpty ||
            camera.id.length > 80 ||
            camera.name.trim().length > 80 ||
            camera.username.length > 128 ||
            CameraFieldValidation.hostError(camera.host) != null ||
            camera.effectivePort(configuration.defaultPort) < 1 ||
            camera.effectivePort(configuration.defaultPort) > 65535 ||
            CameraFieldValidation.pathError(camera.mainPath) != null ||
            CameraFieldValidation.pathError(camera.subPath, optional: true) !=
                null ||
            CameraFieldValidation.pathError(
                  camera.selectedPath,
                  optional: true,
                ) !=
                null ||
            (camera.selectedPath.isNotEmpty &&
                !camera.savedPaths.contains(camera.selectedPath)) ||
            !cameraIds.add(camera.id) ||
            !cameraAddresses.add(addressKey)) {
          throw const FormatException();
        }
      }
      final layouts = LayoutPreset.all.map((layout) => layout.id).toSet();
      final profileNames = <String>{};
      final profileIds = <String>{};
      if (!layouts.contains(configuration.layoutId) ||
          configuration.schemaVersion < 1 ||
          configuration.defaultPort < 1 ||
          configuration.defaultPort > 65535 ||
          configuration.defaultUser.length > 128 ||
          CameraFieldValidation.pathError(configuration.defaultPath) != null ||
          configuration.bufferMs < 100 ||
          configuration.bufferMs > 2000 ||
          configuration.lastMonitorPage < 0 ||
          configuration.lastMonitorPage > 100 ||
          !{
            'light',
            'eco',
            'balanced',
            'quality',
          }.contains(configuration.resourceMode) ||
          configuration.slotCameraIds.length !=
              LayoutPreset.byId(configuration.layoutId).cameraCount ||
          configuration.monitorProfiles.length > 20) {
        throw const FormatException();
      }
      for (final profile in configuration.monitorProfiles) {
        if (profile.id.isEmpty ||
            !profileIds.add(profile.id) ||
            profile.name.trim().isEmpty ||
            profile.name.length > 60 ||
            !profileNames.add(profile.name.toLowerCase()) ||
            !layouts.contains(profile.layoutId) ||
            profile.slotCameraIds.length !=
                LayoutPreset.byId(profile.layoutId).cameraCount) {
          throw const FormatException();
        }
      }
      if (configuration.slotCameraIds.any(
            (id) => id != null && !cameraIds.contains(id),
          ) ||
          configuration.slotCameraIds.whereType<String>().toSet().length !=
              configuration.slotCameraIds.whereType<String>().length) {
        throw const FormatException();
      }
      return await _commit(
        configuration.copyWith(
          resourceMode: configuration.resourceMode == 'eco'
              ? 'light'
              : configuration.resourceMode,
        ),
      );
    } on Object {
      _message =
          'Backup inválido. Confira se é um arquivo do RTSP View e tente novamente.';
      notifyListeners();
      return false;
    }
  }

  void clearMessage() {
    _message = null;
    notifyListeners();
  }

  Future<bool> _commit(AppConfiguration config) async {
    try {
      await _repository.save(config);
      _config = config;
      themeModeListenable.value = themeMode;
      _message = null;
      notifyListeners();
      return true;
    } on Object {
      _message = 'Não foi possível gravar a configuração no dispositivo.';
      notifyListeners();
      return false;
    }
  }

  String _normalizePath(String value) {
    final path = value.trim();
    if (path.isEmpty) return '';
    return path.startsWith('/') ? path : '/$path';
  }

  bool _sameSlots(List<String?> left, List<String?> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }

  @override
  void dispose() {
    themeModeListenable.dispose();
    super.dispose();
  }
}

class AppScope extends InheritedNotifier<AppStore> {
  const AppScope({required AppStore store, required super.child, super.key})
    : super(notifier: store);

  static AppStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    final store = scope?.notifier;
    if (store == null) throw StateError('AppStore indisponível');
    return store;
  }
}
