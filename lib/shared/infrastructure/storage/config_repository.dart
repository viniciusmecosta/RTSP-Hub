import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../../app/data/app_configuration.dart';

class ConfigRepository {
  ConfigRepository({Directory? directory, this.legacyDirectory})
    : _overrideDirectory = directory;

  final Directory? _overrideDirectory;
  final Directory? legacyDirectory;
  Future<void> _saveQueue = Future.value();

  Future<Directory> _directory() async {
    final override = _overrideDirectory;
    if (override != null) {
      await override.create(recursive: true);
      return override;
    }
    final support = await getApplicationSupportDirectory();
    final directory = Directory(
      '${support.path}${Platform.pathSeparator}RTSPHub',
    );
    await directory.create(recursive: true);
    return directory;
  }

  Future<AppConfiguration> load() async {
    final directory = await _directory();
    final primary = File(
      '${directory.path}${Platform.pathSeparator}config.json',
    );
    final backup = File(
      '${directory.path}${Platform.pathSeparator}config.backup.json',
    );
    final previous = File(
      '${directory.path}${Platform.pathSeparator}.config.json.previous',
    );
    if (!await primary.exists()) {
      if (await previous.exists()) {
        try {
          final recovered = await _decode(previous);
          await previous.rename(primary.path);
          return recovered;
        } on Object {
          if (await primary.exists()) rethrow;
          if (!await backup.exists()) rethrow;
        }
      }
      if (await backup.exists()) return _decode(backup);
      final legacyRoots = legacyDirectory == null
          ? _overrideDirectory != null
                ? <Directory>[]
                : await _legacyRoots()
          : [legacyDirectory!];
      FormatException? invalidLegacy;
      for (final root in legacyRoots) {
        for (final name in [
          'config.json',
          'config.backup.json',
          '.config.json.previous',
        ]) {
          final file = File('${root.path}/$name');
          if (!await file.exists()) continue;
          AppConfiguration config;
          try {
            config = await _decode(file);
          } on FormatException catch (error) {
            invalidLegacy = error;
            continue;
          } on TypeError {
            invalidLegacy = const FormatException(
              'Configuração anterior inválida.',
            );
            continue;
          }
          await save(config);
          return config;
        }
      }
      if (invalidLegacy != null) throw invalidLegacy;
      return const AppConfiguration();
    }
    try {
      return await _decode(primary);
    } on Object {
      if (await backup.exists()) {
        final recovered = await _decode(backup);
        try {
          await backup.copy(primary.path);
        } on FileSystemException {
          return recovered;
        }
        return recovered;
      }
      rethrow;
    }
  }

  Future<List<Directory>> _legacyRoots() async {
    final support = await getApplicationSupportDirectory();
    final paths = {
      support.path,
      support.path
          .replaceAll('rtsp_hub', 'rtsp_view')
          .replaceAll('rtspHub', 'rtspView'),
      support.path.replaceAll('RTSP Hub', 'RTSP View'),
    };
    paths.add(
      support.path
          .replaceAll('rtsp_view', 'rtsp_hub')
          .replaceAll('rtspView', 'rtspHub'),
    );
    return [
      for (final path in paths) Directory('$path/RTSPHub'),
      for (final path in paths) Directory('$path/RTSPView'),
    ];
  }

  Future<void> save(AppConfiguration config) {
    final result = _saveQueue.then((_) => _save(config));
    _saveQueue = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    return result;
  }

  Future<void> _save(AppConfiguration config) async {
    final directory = await _directory();
    final primary = File(
      '${directory.path}${Platform.pathSeparator}config.json',
    );
    final backup = File(
      '${directory.path}${Platform.pathSeparator}config.backup.json',
    );
    final temporary = File(
      '${directory.path}${Platform.pathSeparator}.config.json.tmp',
    );
    final previous = File(
      '${directory.path}${Platform.pathSeparator}.config.json.previous',
    );
    final contents = const JsonEncoder.withIndent(
      '  ',
    ).convert(config.toJson());
    await temporary.writeAsString(contents, flush: true);
    if (await primary.exists()) {
      try {
        await _decode(primary);
        if (await backup.exists()) await backup.delete();
        await primary.copy(backup.path);
      } on Object {
        if (!await backup.exists()) {
          await temporary.delete();
          rethrow;
        }
        await _decode(backup);
      }
    }
    try {
      if (await previous.exists()) await previous.delete();
      if (await primary.exists()) await primary.rename(previous.path);
      await temporary.rename(primary.path);
      if (await previous.exists()) await previous.delete();
    } on Object {
      if (!await primary.exists() && await previous.exists()) {
        await previous.rename(primary.path);
      }
      rethrow;
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  Future<AppConfiguration> _decode(File file) async {
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map) throw const FormatException('Configuração inválida');
    final config = AppConfiguration.fromJson(
      Map<String, Object?>.from(decoded),
    );
    if (config.schemaVersion != 1) {
      throw FormatException(
        'Versão de configuração não suportada: ${config.schemaVersion}',
      );
    }
    return config;
  }
}
