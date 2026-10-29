import 'package:holyquran/data/repositories/download_settings_repository.dart';
import 'package:holyquran/data/repositories/recitation_download_repository.dart';
import 'package:holyquran/data/repositories/recitation_repository.dart';
import 'package:holyquran/data/services/catalogue_service.dart';
import 'package:holyquran/data/services/connectivity_service.dart';
import 'package:holyquran/data/services/download_service.dart';
import 'package:holyquran/data/services/free_space_service.dart';
import 'package:holyquran/data/services/recitation_file_store.dart';

/// The downloads of recitation audio on the device's services: `https`
/// only, files under `recitations/` in application support where
/// [PackRecitationRepository] looks for them. What a recitation offers is
/// read from its installed pack through [recitations]. The downloads start
/// on the Wi-Fi-only choice in [settings] and follow it for as long as the
/// app lives, whichever screen changes it.
///
/// [downloads] is the service the pack installer uses: the plugin keeps one
/// callback for its group, so a second service would take the installer's
/// events from it. For the area that provides the installer and the
/// recitations, which no area does yet.
LocalRecitationDownloadRepository recitationDownloadRepository({
  required PackRecitationRepository recitations,
  required DownloadService downloads,
  required DownloadSettingsRepository settings,
}) => downloadsOnSettings(
  settings,
  ({required wifiOnly}) => LocalRecitationDownloadRepository(
    contents: recitations.contents,
    downloads: downloads,
    urlCheck: const HttpUrlCheck(),
    connectivity: PlusConnectivityService(),
    freeSpace: const DiskFreeSpaceService(),
    store: RecitationFileStore(
      audioDirectory: () async =>
          '${await applicationSupportPath()}/${RecitationFileStore.directoryName}',
    ),
    policy: UrlPolicy.httpsOnly,
    wifiOnly: wifiOnly,
  ),
);

/// The downloads [create] makes, started on the Wi-Fi-only choice in
/// [settings] and following it from then on.
T downloadsOnSettings<T extends RecitationDownloadRepository>(
  DownloadSettingsRepository settings,
  T Function({required bool wifiOnly}) create,
) {
  final downloads = create(wifiOnly: settings.wifiOnly);
  followWifiOnly(downloads, settings);
  return downloads;
}

/// Passes each change of the Wi-Fi-only choice in [settings] to [downloads].
/// It is called once, for the repository the composition root keeps for the
/// app's lifetime, and its listener lasts as long as [settings], which the
/// app keeps too.
void followWifiOnly(
  RecitationDownloadRepository downloads,
  DownloadSettingsRepository settings,
) => settings.addListener(() => downloads.setWifiOnly(settings.wifiOnly));
