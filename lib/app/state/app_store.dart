import 'dart:async';
import '../../features/camera_catalog/data/camera_snapshot_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../features/camera_catalog/domain/camera_device.dart';
import '../../features/camera_catalog/domain/camera_field_validation.dart';
import '../../features/layouts/domain/layout_preset.dart';
import '../../features/layouts/domain/saved_monitor_profile.dart';
import '../../shared/infrastructure/secure_store/credential_store.dart';
import '../../shared/infrastructure/storage/config_repository.dart';
import '../data/app_backup_service.dart';
import '../data/app_configuration.dart';

class AppStore extends ChangeNotifier {
  static const _networkDiscoveryCredentialId = '__network_discovery__';
  AppStore({
    ConfigRepository? repository,
    CredentialStore? credentials,
    CameraSnapshotStore? snapshotStore,
    AppBackupService? backupService,
  }) : _repository = repository ?? ConfigRepository(),
       _credentials = credentials ?? CredentialStore(),
       snapshots = snapshotStore ?? CameraSnapshotStore(),
       _backupService = backupService ?? const AppBackupService();

  final CameraSnapshotStore snapshots;
  final ConfigRepository _repository;
  final CredentialStore _credentials;
  final AppBackupService _backupService;
  final Map<String, String> _passwords = {};
  final Set<String> _missingPasswords = {};
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
  LayoutPreset get activeLayout =>
      LayoutPreset.byId(_config.layoutId, cameraCount: _config.cameras.length);

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
    _passwords.clear();
    _missingPasswords.clear();
    notifyListeners();
    try {
      _config = await _repository.load();
      themeModeListenable.value = themeMode;
      final validIds = _config.cameras.map((camera) => camera.id).toSet();
      final slots = _config.slotCameraIds
          .map((id) => id != null && validIds.contains(id) ? id : null)
          .toList();
      if (_config.layoutId == 'GRID_ALL') {
        final allSlots = _allCameraSlots(_config.cameras, slots);
        if (!_sameSlots(allSlots, slots)) {
          _config = _config.copyWith(slotCameraIds: allSlots);
        }
      } else if (slots.length != activeLayout.cameraCount ||
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

  CameraDevice resolveCamera(CameraDevice camera) => camera.resolved(
    defaultPort: _config.defaultPort,
    defaultUser: _config.defaultUser,
    defaultPath: _config.defaultPath,
    defaultSubPath: _config.defaultSubPath,
  );

  CameraDevice? cameraForEndpoint(String host, {int? port, String? path}) {
    final matches = cameras
        .where(
          (camera) =>
              camera.host.toLowerCase() == host.toLowerCase() &&
              (port == null ||
                  camera.effectivePort(_config.defaultPort) == port),
        )
        .toList();
    if (path != null) {
      for (final camera in matches) {
        final resolved = resolveCamera(camera);
        if (resolved.mainPath == path ||
            resolved.subPath == path ||
            camera.savedPaths.contains(path)) {
          return camera;
        }
      }
    }
    return matches.length == 1 ? matches.single : null;
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
    Uint8List? thumbnail,
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
          resolveCamera(camera).mainPath == _normalizePath(path),
    )) {
      _message =
          'Já existe uma câmera cadastrada com o mesmo endereço, porta e caminho.';
      notifyListeners();
      return false;
    }
    final isNewCamera = id.isEmpty;
    if (isNewCamera && username.trim().isEmpty && password.isEmpty) {
      useGlobalCredentials = true;
    }
    final normalizedMain = _normalizePath(mainPath);
    final normalizedSub = _normalizePath(subPath);
    final allSavedPaths = <String>{
      if (normalizedMain.isNotEmpty) normalizedMain,
      if (normalizedSub.isNotEmpty) normalizedSub,
      ...savedPaths.map(_normalizePath).where((p) => p.isNotEmpty),
    }.toList();

    final camera = CameraDevice(
      id: isNewCamera ? const Uuid().v4() : id,
      name: name.trim().isEmpty ? normalizedHost : name.trim(),
      host: normalizedHost,
      port: port.trim().isEmpty ? null : parsedPort,
      username: useGlobalCredentials ? '' : username.trim(),
      useGlobalCredentials: useGlobalCredentials,
      mainPath: normalizedMain,
      subPath: normalizedSub,
      savedPaths: allSavedPaths,
      selectedPath: allSavedPaths.contains(selectedPath) ? selectedPath : '',
    );
    final previousCamera = _config.cameras
        .where((item) => item.id == camera.id)
        .firstOrNull;
    _missingPasswords.remove(camera.id);
    String? previousPassword;
    try {
      if (previousCamera != null) {
        previousPassword = await _credentials.read(camera.id);
      }
    } on Object {
      _message = 'Não foi possível acessar o cofre. A câmera não foi alterada.';
      notifyListeners();
      return false;
    }
    try {
      if (!useGlobalCredentials && password.isNotEmpty) {
        await _credentials.write(camera.id, password);
        _passwords[camera.id] = password;
      } else {
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
        {
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
      var thumbnailUpdated = true;
      if (thumbnail != null) {
        thumbnailUpdated = await snapshots.save(camera.id, thumbnail);
      } else if (previousCamera != null &&
          (previousCamera.host != camera.host ||
              previousCamera.port != camera.port ||
              previousCamera.mainPath != camera.mainPath ||
              previousCamera.username != camera.username ||
              previousCamera.useGlobalCredentials !=
                  camera.useGlobalCredentials ||
              previousPassword != (password.isEmpty ? null : password))) {
        thumbnailUpdated = await snapshots.remove(camera.id);
      }
      _message = thumbnailUpdated
          ? 'Câmera salva neste dispositivo.'
          : 'Câmera salva, mas não foi possível atualizar a miniatura.';
      return true;
    } on Object {
      {
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
        : await specificPasswordFor(source) ?? '';
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
      final thumbnailRemoved = await snapshots.remove(id);
      await _credentials.delete(id);
      _passwords.remove(id);
      _missingPasswords.remove(id);
      _message = thumbnailRemoved
          ? null
          : 'Câmera removida, mas não foi possível apagar a miniatura antiga.';
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
              '${camera.host.toLowerCase()}:${camera.effectivePort(_config.defaultPort)}:${resolveCamera(camera).mainPath}',
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
        port: port == _config.defaultPort ? null : port,
        username: '',
        mainPath: path == _config.defaultPath ? '' : path,
        subPath: subPath == _config.defaultSubPath ? '' : subPath,
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
    final password = await specificPasswordFor(camera);
    return password == null || password.isEmpty
        ? networkDiscoveryPassword()
        : password;
  }

  Future<String?> specificPasswordFor(CameraDevice camera) async {
    final memory = _passwords[camera.id];
    if (memory != null) return memory;
    if (_missingPasswords.contains(camera.id)) return null;
    try {
      final password = await _credentials.read(camera.id);
      if (password == null) {
        _missingPasswords.add(camera.id);
      } else {
        _passwords[camera.id] = password;
      }
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
    if (_missingPasswords.contains(_networkDiscoveryCredentialId)) {
      return null;
    }
    try {
      final password = await _credentials.read(_networkDiscoveryCredentialId);
      if (password == null) {
        _missingPasswords.add(_networkDiscoveryCredentialId);
      } else {
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
  }) => saveGlobalConnection(
    username: username,
    password: password,
    port: '${_config.defaultPort}',
    mainPath: _config.defaultPath,
    subPath: _config.defaultSubPath,
  );

  Future<bool> saveGlobalConnection({
    required String username,
    required String password,
    required String port,
    required String mainPath,
    String subPath = '',
  }) async {
    final parsedPort = int.tryParse(port.trim());
    if (parsedPort == null ||
        CameraFieldValidation.portError(port) != null ||
        username.trim().length > 128 ||
        password.length > 1024 ||
        CameraFieldValidation.pathError(mainPath) != null ||
        CameraFieldValidation.pathError(subPath, optional: true) != null) {
      _message = 'Confira usuário, senha, porta e caminhos da conexão global.';
      notifyListeners();
      return false;
    }
    String? previous;
    try {
      previous = await _credentials.read(_networkDiscoveryCredentialId);
    } on Object {
      _message = 'Não foi possível acessar o cofre seguro.';
      notifyListeners();
      return false;
    }
    try {
      _missingPasswords.remove(_networkDiscoveryCredentialId);
      await _credentials.write(_networkDiscoveryCredentialId, password);
      if (!await _commit(
        _config.copyWith(
          defaultUser: username.trim(),
          defaultPort: parsedPort,
          defaultPath: _normalizePath(mainPath),
          defaultSubPath: _normalizePath(subPath),
        ),
      )) {
        throw StateError('configuration write failed');
      }
      _passwords.remove(_networkDiscoveryCredentialId);
      if (password.isNotEmpty) {
        _passwords[_networkDiscoveryCredentialId] = password;
      }
      notifyListeners();
      return true;
    } on Object {
      try {
        if (previous == null) {
          await _credentials.delete(_networkDiscoveryCredentialId);
        } else {
          await _credentials.write(_networkDiscoveryCredentialId, previous);
        }
      } on Object {
        _message =
            'O cofre ficou indisponível. Confira as credenciais globais antes de conectar.';
        notifyListeners();
        return false;
      }
      _message =
          'Não foi possível salvar a conexão global. Os valores anteriores foram mantidos.';
      notifyListeners();
      return false;
    }
  }

  Future<void> setLayout(String layoutId) async {
    final previous = _config.slotCameraIds;
    final count = LayoutPreset.byId(
      layoutId,
      cameraCount: _config.cameras.length,
    ).cameraCount;
    final slots = List<String?>.generate(
      count,
      (index) => index < previous.length ? previous[index] : null,
    );
    await _commit(_config.copyWith(layoutId: layoutId, slotCameraIds: slots));
  }

  Future<void> setSlot(int index, String? cameraId) async {
    final slots = [..._config.slotCameraIds];
    if (index < 0 || index >= slots.length) return;
    if (_config.layoutId == 'GRID_ALL') {
      if (cameraId == null) return;
      final previous = slots.indexOf(cameraId);
      if (previous >= 0 && previous != index) {
        slots[previous] = slots[index];
      }
      slots[index] = cameraId;
      await _commit(_config.copyWith(slotCameraIds: slots));
      return;
    }
    for (var i = 0; i < slots.length; i++) {
      if (slots[i] == cameraId && cameraId != null) slots[i] = null;
    }
    slots[index] = cameraId;
    await _commit(_config.copyWith(slotCameraIds: slots));
  }

  Future<void> clearSlots() async {
    if (_config.layoutId == 'GRID_ALL') return;
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
    final layout = LayoutPreset.byId(
      profile.layoutId,
      cameraCount: _config.cameras.length,
    );
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

  static const profileExportFormat = AppBackupService.profileExportFormat;
  static const maxBackupBytes = AppBackupService.maxBackupBytes;

  String exportMonitorProfiles([Set<String>? profileIds]) => _backupService
      .exportMonitorProfiles(config: _config, profileIds: profileIds);

  Future<int?> importMonitorProfiles(String source) =>
      _backupService.importMonitorProfiles(
        source: source,
        currentConfig: _config,
        commit: _commit,
        setMessage: (msg) {
          _message = msg;
          notifyListeners();
        },
      );

  Future<String> exportBackup() => _backupService.exportBackup(
    config: _config,
    credentials: _credentials,
    snapshots: snapshots,
    getCurrentConfig: () => _config,
  );

  String exportConfiguration() => _backupService.exportConfiguration(_config);

  Future<bool> importConfiguration(String source) async {
    _missingPasswords.clear();
    return _backupService.importConfiguration(
      source: source,
      currentConfig: _config,
      credentials: _credentials,
      snapshots: snapshots,
      commit: _commit,
      passwordsCache: _passwords,
      setMessage: (msg) {
        _message = msg;
        notifyListeners();
      },
      notify: notifyListeners,
    );
  }

  void clearMessage() {
    _message = null;
    notifyListeners();
  }

  Future<bool> _commit(AppConfiguration config) async {
    try {
      if (config.layoutId == 'GRID_ALL') {
        config = config.copyWith(
          slotCameraIds: _allCameraSlots(config.cameras, config.slotCameraIds),
        );
      }
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

  List<String?> _allCameraSlots(
    List<CameraDevice> cameras,
    List<String?> previous,
  ) {
    final valid = cameras.map((camera) => camera.id).toSet();
    final seen = <String>{};
    final ordered = <String?>[
      for (final id in previous)
        if (id != null && valid.contains(id) && seen.add(id)) id,
      for (final camera in cameras)
        if (seen.add(camera.id)) camera.id,
    ];
    return ordered.isEmpty ? [null] : ordered;
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
