import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/config/providers/recitation_download_providers.dart';
import 'package:holyquran/data/repositories/download_settings_repository.dart';

import '../../ui/features/resources/recitation_downloads_fixtures.dart';

void main() {
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
