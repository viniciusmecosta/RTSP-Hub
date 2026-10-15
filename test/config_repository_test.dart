import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rtsp_hub/app/data/app_configuration.dart';
import 'package:rtsp_hub/shared/infrastructure/storage/config_repository.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('rtsp-hub-config-');
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test(
    'migrates the previous app directory without deleting its data',
    () async {
      final legacy = Directory('${directory.path}/legacy');
      final target = Directory('${directory.path}/new');
      await ConfigRepository(
        directory: legacy,
      ).save(const AppConfiguration(defaultUser: 'legacy-user'));
      final repository = ConfigRepository(
        directory: target,
        legacyDirectory: legacy,
      );
      expect((await repository.load()).defaultUser, 'legacy-user');
      expect(await File('${legacy.path}/config.json').exists(), isTrue);
      await repository.save(const AppConfiguration(defaultUser: 'new-user'));
      expect((await repository.load()).defaultUser, 'new-user');
    },
  );

  test('recovers a legacy backup when its primary file is corrupt', () async {
    final legacy = Directory('${directory.path}/legacy');
    final target = Directory('${directory.path}/new');
    final previous = ConfigRepository(directory: legacy);
    await previous.save(const AppConfiguration(defaultUser: 'backup-user'));
    await previous.save(const AppConfiguration(defaultUser: 'primary-user'));
    await File('${legacy.path}/config.json').writeAsString('{invalid');

    final repository = ConfigRepository(
      directory: target,
      legacyDirectory: legacy,
    );
    expect((await repository.load()).defaultUser, 'backup-user');
  });

  test('reports corrupt legacy data instead of opening an empty app', () async {
    final legacy = Directory('${directory.path}/legacy');
    await legacy.create();
    await File('${legacy.path}/config.json').writeAsString('{invalid');
    final repository = ConfigRepository(
      directory: Directory('${directory.path}/new'),
      legacyDirectory: legacy,
    );

    await expectLater(repository.load(), throwsFormatException);
  });

  test('recovers a corrupt primary and allows saving afterward', () async {
    final repository = ConfigRepository(directory: directory);
    await repository.save(const AppConfiguration(defaultUser: 'before'));
    await repository.save(const AppConfiguration(defaultUser: 'current'));
    await File('${directory.path}/config.json').writeAsString('{invalid');

    final recovered = await repository.load();
    expect(recovered.defaultUser, 'before');
    await repository.save(const AppConfiguration(defaultUser: 'after'));
    expect((await repository.load()).defaultUser, 'after');
  });

  test('serializes concurrent saves and preserves the last value', () async {
    final repository = ConfigRepository(directory: directory);
    await Future.wait([
      for (var index = 0; index < 12; index++)
        repository.save(AppConfiguration(defaultUser: 'user$index')),
    ]);

    expect((await repository.load()).defaultUser, 'user11');
  });

  test('restores interrupted file rename from previous version', () async {
    final repository = ConfigRepository(directory: directory);
    await repository.save(const AppConfiguration(defaultUser: 'saved'));
    await File(
      '${directory.path}/config.json',
    ).rename('${directory.path}/.config.json.previous');

    expect((await repository.load()).defaultUser, 'saved');
    expect(await File('${directory.path}/config.json').exists(), isTrue);
  });
}
