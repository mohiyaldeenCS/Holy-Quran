import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/config/providers/recitation_download_providers.dart';
import 'package:holyquran/data/repositories/download_settings_repository.dart';

import '../../ui/features/resources/recitation_downloads_fixtures.dart';

void main() {
  for (final wifiOnly in [true, false]) {
    test('starts the downloads on Wi-Fi only $wifiOnly as the settings '
        'have it', () async {
      final settings = InMemoryDownloadSettingsRepository(wifiOnly: wifiOnly);
      late bool started;

      downloadsOnSettings(settings, ({required wifiOnly}) {
        started = wifiOnly;
        return FakeRecitationDownloadRepository();
      });

      expect(started, wifiOnly);
    });
  }

  test('follows the settings from the start', () async {
    final settings = InMemoryDownloadSettingsRepository();
    final downloads = downloadsOnSettings(
      settings,
      ({required wifiOnly}) => FakeRecitationDownloadRepository(),
    );

    await settings.setWifiOnly(false);

    expect(downloads.calls, [('setWifiOnly', 'false')]);
  });

  test('passes each change of Wi-Fi only to the downloads', () async {
    final settings = InMemoryDownloadSettingsRepository();
    final downloads = FakeRecitationDownloadRepository();
    followWifiOnly(downloads, settings);

    await settings.setWifiOnly(false);
    await settings.setWifiOnly(true);

    expect(
      downloads.calls.where((c) => c.$1 == 'setWifiOnly').map((c) => c.$2),
      ['false', 'true'],
    );
  });
}
