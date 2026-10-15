import 'package:flutter_test/flutter_test.dart';
import 'package:rtsp_hub/app/data/app_configuration.dart';

void main() {
  test('migrates legacy resource mode and restores the last used screen', () {
    final configuration = AppConfiguration.fromJson({
      'settings': {
        'resourceMode': 'eco',
        'startupSection': 'last',
        'lastSection': 'monitor',
        'lastMonitorPage': 3,
      },
    });

    expect(configuration.resourceMode, 'light');
    expect(configuration.startupSection, 'last');
    expect(configuration.lastSection, 'monitor');
    expect(configuration.lastMonitorPage, 3);
  });

  test('clamps corrupt last monitor page values', () {
    final configuration = AppConfiguration.fromJson({
      'settings': {'lastMonitorPage': 999},
    });

    expect(configuration.lastMonitorPage, 100);
  });
}
