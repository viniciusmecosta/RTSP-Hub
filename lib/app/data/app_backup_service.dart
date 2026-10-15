import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../features/camera_catalog/data/camera_snapshot_store.dart';
import '../../features/camera_catalog/domain/camera_device.dart';
import '../../features/camera_catalog/domain/camera_field_validation.dart';
import '../../features/layouts/domain/layout_preset.dart';
import '../../features/layouts/domain/saved_monitor_profile.dart';
import '../../shared/infrastructure/secure_store/credential_store.dart';
import 'app_configuration.dart';

class AppBackupService {
  const AppBackupService();

  static const profileExportFormat = 'rtsp-hub-profiles';
  static const maxBackupBytes = 64 * 1024 * 1024;
  static const networkDiscoveryCredentialId = '__network_discovery__';

  String exportMonitorProfiles({
    required AppConfiguration config,
    Set<String>? profileIds,
  }) {
    final profiles = config.monitorProfiles
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
      'version': 2,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'profiles': profiles.map((profile) => profile.toJson()).toList(),
      'cameras': config.cameras
          .where((camera) => cameraIds.contains(camera.id))
          .map(
            (camera) => {
              ...camera.toJson(),
              'port': camera.effectivePort(config.defaultPort),
            },
          )
          .toList(),
    });
  }

  Future<int?> importMonitorProfiles({
    required String source,
    required AppConfiguration currentConfig,
    required Future<bool> Function(AppConfiguration) commit,
    required void Function(String) setMessage,
  }) async {
    final List<SavedMonitorProfile> incomingProfiles;
    final List<CameraDevice> incomingCameras;
    try {
      if (utf8.encode(source).length > maxBackupBytes) {
        throw const FormatException();
      }
      final decoded = jsonDecode(source);
      if (decoded is! Map ||
          !{
            profileExportFormat,
            'rtsp-view-profiles',
          }.contains(decoded['format']) ||
          !{1, 2}.contains(decoded['version'])) {
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
      final incomingIds = <String>{};
      for (final camera in incomingCameras) {
        if (camera.id == networkDiscoveryCredentialId ||
            camera.id.isEmpty ||
            !incomingIds.add(camera.id) ||
            camera.name.trim().isEmpty ||
            camera.name.length > 80 ||
            camera.username.length > 128 ||
            CameraFieldValidation.hostError(camera.host) != null ||
            (decoded['version'] == 2 && camera.port == null) ||
            CameraFieldValidation.portError(
                  '${camera.effectivePort(currentConfig.defaultPort)}',
                ) !=
                null ||
            CameraFieldValidation.pathError(camera.mainPath, optional: true) !=
                null ||
            CameraFieldValidation.pathError(camera.subPath, optional: true) !=
                null ||
            camera.savedPaths.any(
              (path) => CameraFieldValidation.pathError(path) != null,
            ) ||
            CameraFieldValidation.pathError(
                  camera.selectedPath,
                  optional: true,
                ) !=
                null ||
            (camera.selectedPath.isNotEmpty &&
                !camera.savedPaths.contains(camera.selectedPath))) {
          throw const FormatException();
        }
      }
      for (final profile in incomingProfiles) {
        if (profile.id.isEmpty ||
            profile.name.trim().isEmpty ||
            profile.name.length > 60 ||
            !LayoutPreset.all.any((layout) => layout.id == profile.layoutId) ||
            profile.slotCameraIds.length !=
                LayoutPreset.byId(
                  profile.layoutId,
                  cameraCount: profile.slotCameraIds.length,
                ).cameraCount ||
            profile.slotCameraIds.any(
              (id) => id != null && !incomingIds.contains(id),
            ) ||
            profile.slotCameraIds.whereType<String>().toSet().length !=
                profile.slotCameraIds.whereType<String>().length) {
          throw const FormatException();
        }
      }
    } on Object {
      setMessage('O arquivo não é uma exportação de perfis válida.');
      return null;
    }
    String keyOf(CameraDevice camera) =>
        '${camera.host.toLowerCase()}:${camera.effectivePort(currentConfig.defaultPort)}:${camera.mainPath}';
    final cameras = [...currentConfig.cameras];
    final byKey = {for (final camera in cameras) keyOf(camera): camera.id};
    final idMap = <String, String>{};
    for (final camera in incomingCameras) {
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
        useGlobalCredentials: camera.useGlobalCredentials,
        savedPaths: camera.savedPaths,
        selectedPath: camera.selectedPath,
      );
      cameras.add(created);
      byKey[keyOf(created)] = created.id;
      idMap[camera.id] = created.id;
    }
    final profiles = [...currentConfig.monitorProfiles];
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
      setMessage('Nenhum perfil novo pôde ser importado.');
      return 0;
    }
    final saved = await commit(
      currentConfig.copyWith(cameras: cameras, monitorProfiles: profiles),
    );
    return saved ? added : null;
  }

  Future<String> exportBackup({
    required AppConfiguration config,
    required CredentialStore credentials,
    required CameraSnapshotStore snapshots,
    required AppConfiguration Function() getCurrentConfig,
  }) async {
    final creds = <String, String?>{};
    final images = <String, String>{};
    var imageBytes = 0;
    for (final id in [
      networkDiscoveryCredentialId,
      ...config.cameras.map((camera) => camera.id),
    ]) {
      creds[id] = await credentials.read(id);
    }
    for (final camera in config.cameras) {
      final bytes = await snapshots.read(camera.id);
      if (bytes != null) {
        imageBytes += bytes.length;
        if (imageBytes > 40 * 1024 * 1024) {
          throw const FormatException('Miniaturas excedem o limite de backup.');
        }
        images[camera.id] = base64Encode(bytes);
      }
    }
    if (!identical(config, getCurrentConfig())) {
      throw StateError(
        'As configurações mudaram durante o backup. Tente novamente.',
      );
    }
    return jsonEncode({
      'format': 'rtsp_hub_backup',
      'version': 1,
      'configuration': config.toJson(),
      'credentials': creds,
      'thumbnails': images,
    });
  }

  Future<bool> restoreCompleteBackup({
    required AppConfiguration config,
    required Map decoded,
    required AppConfiguration currentConfig,
    required CredentialStore credentials,
    required CameraSnapshotStore snapshots,
    required Future<bool> Function(AppConfiguration) commit,
    required Map<String, String> passwordsCache,
    required void Function(String) setMessage,
  }) async {
    if (decoded['version'] != 1 ||
        decoded['credentials'] is! Map ||
        decoded['thumbnails'] is! Map) {
      throw const FormatException();
    }
    final allowed = {
      networkDiscoveryCredentialId,
      ...config.cameras.map((camera) => camera.id),
    };
    final creds = Map<String, Object?>.from(decoded['credentials'] as Map);
    if (creds.keys.toSet().length != allowed.length ||
        !allowed.containsAll(creds.keys) ||
        creds.values.any(
          (value) => value != null && (value is! String || value.length > 1024),
        )) {
      throw const FormatException();
    }
    final rawImages = Map<String, Object?>.from(decoded['thumbnails'] as Map);
    final images = <String, Uint8List>{};
    for (final entry in rawImages.entries) {
      if (entry.key == networkDiscoveryCredentialId ||
          !allowed.contains(entry.key) ||
          entry.value is! String) {
        throw const FormatException();
      }
      final bytes = base64Decode(entry.value as String);
      if (bytes.length > 4 * 1024 * 1024 ||
          bytes.length < 24 ||
          !listEquals(bytes.take(8).toList(), [
            137,
            80,
            78,
            71,
            13,
            10,
            26,
            10,
          ])) {
        throw const FormatException();
      }
      final header = ByteData.sublistView(bytes);
      if (header.getUint32(16) > 640 ||
          header.getUint32(20) > 4096 ||
          header.getUint32(16) == 0 ||
          header.getUint32(20) == 0) {
        throw const FormatException();
      }
      images[entry.key] = bytes;
    }
    final affected = {
      ...allowed,
      ...currentConfig.cameras.map((camera) => camera.id),
    };
    final oldCredentials = <String, String?>{};
    final oldImages = <String, Uint8List?>{};
    for (final id in affected) {
      oldCredentials[id] = await credentials.read(id);
      if (id != networkDiscoveryCredentialId) {
        oldImages[id] = await snapshots.read(id);
      }
    }
    try {
      for (final id in affected) {
        final secret = creds[id] as String?;
        if (secret == null || secret.isEmpty) {
          await credentials.delete(id);
        } else {
          await credentials.write(id, secret);
        }
      }
      for (final id in oldImages.keys) {
        final bytes = images[id];
        if (bytes != null) {
          if (!await snapshots.save(id, bytes)) {
            throw StateError('snapshot write failed');
          }
        } else {
          if (!await snapshots.remove(id)) {
            throw StateError('snapshot removal failed');
          }
        }
      }
      if (!await commit(config)) {
        throw StateError('configuration write failed');
      }
      passwordsCache.clear();
      for (final entry in creds.entries) {
        if (entry.value is String && (entry.value as String).isNotEmpty) {
          passwordsCache[entry.key] = entry.value as String;
        }
      }
      return true;
    } on Object {
      var restored = true;
      for (final entry in oldCredentials.entries) {
        try {
          if (entry.value == null) {
            await credentials.delete(entry.key);
          } else {
            await credentials.write(entry.key, entry.value!);
          }
        } on Object {
          restored = false;
        }
      }
      for (final entry in oldImages.entries) {
        if (entry.value == null) {
          restored = await snapshots.remove(entry.key) && restored;
        } else {
          restored = await snapshots.save(entry.key, entry.value!) && restored;
        }
      }
      passwordsCache.clear();
      setMessage(
        restored
            ? 'Não foi possível restaurar. Os dados anteriores foram mantidos.'
            : 'A restauração foi interrompida pelo armazenamento. Confira as credenciais antes de conectar.',
      );
      return false;
    }
  }

  String exportConfiguration(AppConfiguration config) =>
      const JsonEncoder.withIndent('  ').convert(config.toJson());

  Future<bool> importConfiguration({
    required String source,
    required AppConfiguration currentConfig,
    required CredentialStore credentials,
    required CameraSnapshotStore snapshots,
    required Future<bool> Function(AppConfiguration) commit,
    required Map<String, String> passwordsCache,
    required void Function(String) setMessage,
    required void Function() notify,
  }) async {
    if (utf8.encode(source).length > maxBackupBytes) {
      setMessage('O arquivo de backup excede o limite de 64 MB.');
      return false;
    }
    try {
      final decoded = jsonDecode(source);
      if (decoded is! Map) throw const FormatException();
      final complete = decoded['format'] == 'rtsp_hub_backup';
      final rawConfiguration = complete ? decoded['configuration'] : decoded;
      if (rawConfiguration is! Map ||
          rawConfiguration['cameras'] is! List ||
          rawConfiguration['settings'] is! Map ||
          rawConfiguration['layout'] is! Map) {
        throw const FormatException();
      }
      final configuration = AppConfiguration.fromJson(
        Map<String, Object?>.from(rawConfiguration),
      );
      if (configuration.schemaVersion > currentConfig.schemaVersion) {
        throw const FormatException();
      }
      final cameraIds = <String>{};
      final cameraAddresses = <String>{};
      for (final camera in configuration.cameras) {
        final addressKey =
            '${camera.host.toLowerCase()}:${camera.effectivePort(configuration.defaultPort)}:${camera.mainPath.isEmpty ? configuration.defaultPath : camera.mainPath}';
        if (camera.id == networkDiscoveryCredentialId ||
            camera.id.isEmpty ||
            camera.id.length > 80 ||
            camera.name.trim().length > 80 ||
            camera.username.length > 128 ||
            CameraFieldValidation.hostError(camera.host) != null ||
            camera.effectivePort(configuration.defaultPort) < 1 ||
            camera.effectivePort(configuration.defaultPort) > 65535 ||
            CameraFieldValidation.pathError(camera.mainPath, optional: true) !=
                null ||
            CameraFieldValidation.pathError(camera.subPath, optional: true) !=
                null ||
            CameraFieldValidation.pathError(
                  camera.selectedPath,
                  optional: true,
                ) !=
                null ||
            (camera.selectedPath.isNotEmpty &&
                !camera.savedPaths.contains(camera.selectedPath)) ||
            camera.savedPaths.any(
              (path) => CameraFieldValidation.pathError(path) != null,
            ) ||
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
          CameraFieldValidation.pathError(
                configuration.defaultSubPath,
                optional: true,
              ) !=
              null ||
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
              LayoutPreset.byId(
                configuration.layoutId,
                cameraCount: configuration.cameras.length,
              ).cameraCount ||
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
            profile.slotCameraIds.any(
              (id) => id != null && !cameraIds.contains(id),
            ) ||
            profile.slotCameraIds.length !=
                LayoutPreset.byId(
                  profile.layoutId,
                  cameraCount: profile.slotCameraIds.length,
                ).cameraCount) {
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
      if (complete) {
        final success = await restoreCompleteBackup(
          config: configuration,
          decoded: decoded,
          currentConfig: currentConfig,
          credentials: credentials,
          snapshots: snapshots,
          commit: commit,
          passwordsCache: passwordsCache,
          setMessage: setMessage,
        );
        if (success) notify();
        return success;
      }
      return await commit(
        configuration.copyWith(
          resourceMode: configuration.resourceMode == 'eco'
              ? 'light'
              : configuration.resourceMode,
        ),
      );
    } catch (error) {
      setMessage(
        error is FormatException || error is TypeError
            ? 'Backup inválido. Confira se é um arquivo do RTSP Hub e tente novamente.'
            : 'Não foi possível acessar o armazenamento ou o cofre para restaurar o backup.',
      );
      return false;
    }
  }
}
