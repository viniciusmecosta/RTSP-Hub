import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../../app/data/app_configuration.dart';

class ConfigRepository {
  ConfigRepository({Directory? directory}) : _overrideDirectory = directory;

  final Directory? _overrideDirectory;
  Future<void> _saveQueue = Future.value();

  Future<Directory> _directory() async {
    final override = _overrideDirectory;
    if (override != null) {
      await override.create(recursive: true);
      return override;
    }
    final support = await getApplicationSupportDirectory();
    final directory = Directory(
      '${support.path}${Platform.pathSeparator}RTSPView',
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
