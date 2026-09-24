import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../features/camera_catalog/domain/camera_device.dart';
import '../../features/camera_catalog/domain/camera_field_validation.dart';
import '../../features/layouts/domain/layout_preset.dart';
import '../../shared/infrastructure/secure_store/credential_store.dart';
import '../../shared/infrastructure/storage/config_repository.dart';
import '../data/app_configuration.dart';

class AppStore extends ChangeNotifier {
  AppStore({ConfigRepository? repository, CredentialStore? credentials})
    : _repository = repository ?? ConfigRepository(),
      _credentials = credentials ?? CredentialStore();

  final ConfigRepository _repository;
  final CredentialStore _credentials;
  final Map<String, String> _passwords = {};
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

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    try {
      _config = await _repository.load();
      final validIds = _config.cameras.map((camera) => camera.id).toSet();
      final slots = _config.slotCameraIds
          .map((id) => id != null && validIds.contains(id) ? id : null)
          .toList();
      if (slots.length != activeLayout.cameraCount) {
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
    final camera = CameraDevice(
      id: id.isEmpty ? const Uuid().v4() : id,
      name: name.trim().isEmpty ? normalizedHost : name.trim(),
      host: normalizedHost,
      port: port.trim().isEmpty ? null : parsedPort,
      username: username.trim(),
      mainPath: mainPath.trim().isEmpty
          ? _config.defaultPath
          : _normalizePath(mainPath),
      subPath: _normalizePath(subPath),
    );
    final previousPassword = await _credentials.read(camera.id);
    try {
      if (password.isNotEmpty) {
        await _credentials.write(camera.id, password);
        _passwords[camera.id] = password;
      }
      final cameras = [
        ..._config.cameras.where((item) => item.id != camera.id),
        camera,
      ];
      if (!await _commit(_config.copyWith(cameras: cameras))) {
        if (password.isNotEmpty) {
          if (previousPassword == null) {
            await _credentials.delete(camera.id);
          } else {
            await _credentials.write(camera.id, previousPassword);
          }
        }
        return false;
      }
      _message = 'Câmera salva neste dispositivo.';
      return true;
    } on Object {
      if (password.isNotEmpty) {
        try {
          if (previousPassword == null) {
            await _credentials.delete(camera.id);
          } else {
            await _credentials.write(camera.id, previousPassword);
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

  Future<String?> passwordFor(CameraDevice camera) async {
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

  Future<void> setThemeMode(ThemeMode mode) async {
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
  }) async {
    await _commit(
      _config.copyWith(
        defaultPort: defaultPort,
        defaultUser: defaultUser,
        defaultPath: defaultPath,
        bufferMs: bufferMs,
        resourceMode: resourceMode,
        autoFullscreen: autoFullscreen,
        startupSection: startupSection,
      ),
    );
  }

  void clearMessage() {
    _message = null;
    notifyListeners();
  }

  Future<bool> _commit(AppConfiguration config) async {
    try {
      await _repository.save(config);
      _config = config;
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
