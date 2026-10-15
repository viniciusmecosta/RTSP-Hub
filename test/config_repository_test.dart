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
