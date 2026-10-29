import 'dart:io';

import 'package:drift/native.dart';
import 'package:holyquran/config/dependencies.dart';
import 'package:holyquran/config/providers/address_providers.dart';
import 'package:holyquran/config/providers/audio_providers.dart';
import 'package:holyquran/config/providers/catalogue_providers.dart';
import 'package:holyquran/config/providers/links_providers.dart';
import 'package:holyquran/config/providers/pack_install_providers.dart';
import 'package:holyquran/config/providers/quran_providers.dart';
import 'package:holyquran/config/providers/reading_providers.dart';
import 'package:holyquran/config/providers/search_providers.dart';
import 'package:holyquran/config/providers/settings_providers.dart';
import 'package:holyquran/config/providers/share_providers.dart';
import 'package:holyquran/config/providers/tafsir_providers.dart';
import 'package:holyquran/config/providers/user_data_providers.dart';
import 'package:holyquran/config/providers/user_database_providers.dart';
import 'package:holyquran/data/repositories/app_settings_repository.dart';
import 'package:holyquran/data/repositories/catalogue_repository.dart';
import 'package:holyquran/data/repositories/local_pack_repository.dart';
import 'package:holyquran/data/repositories/pack_install_repository.dart';
import 'package:holyquran/data/repositories/pack_integrity_repository.dart';
import 'package:holyquran/data/repositories/pack_quran_text_repository.dart';
import 'package:holyquran/data/repositories/quran_text_repository.dart';
import 'package:holyquran/data/services/base_pack_service.dart';
import 'package:holyquran/data/services/catalogue_service.dart';
import 'package:holyquran/data/services/download_service.dart'
    show HttpUrlCheck, UrlPolicy;
import 'package:holyquran/data/services/installed_packs_store.dart';
import 'package:holyquran/data/services/manifest_signature.dart';
import 'package:holyquran/data/services/pack_file_service.dart';
import 'package:holyquran/data/services/user_database.dart';
import 'package:holyquran/data/services/wakelock_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/single_child_widget.dart';

import 'flow_audio.dart';
import 'flow_downloads.dart';
import 'flow_pack.dart';
import 'flow_server.dart';

/// The screen wakelock plugin, doing nothing.
final class _NoWakelock extends WakelockService {
  const _NoWakelock();

  @override
  Future<void> enable() async {}

  @override
  Future<void> disable() async {}
}

/// Plain HTTP on the loopback address, which a test server speaks.
const _http = UrlPolicy(scheme: 'http');

/// What a run of the flows is served: the directory of the pack the app
/// bundles, and the server of the catalogue and the downloadable packs.
typedef FlowSources = ({Directory bundle, FlowServer server});

/// The app's objects as `main` sets them up, area by area, for one run of the
/// app over the application-support folder that `path_provider` answers
/// with: the user database (a file in that folder), settings, the reading
/// position, the verified base pack copied from [FlowSources.bundle], the
/// installer, the catalogue fetched from [FlowSources.server], the user's
/// data, the player, tafsir, search, sharing, addresses and links. Only the
/// plugins are replaced: the audio engine and its files' locator, the
/// wakelock, the downloader, the network and disk probes, and the drift
/// executor, which a widget test's clock cannot drive in a background isolate;
/// with [start]'s `onDevice` the database is opened as the app opens it.
/// Starting a second session over the same folder is a restart of the app.
final class FlowSession {
  FlowSession._(this.providers, this._dependencies, this.engine);

  /// Starts a session. Run it in `WidgetTester.runAsync`: it reads files, the
  /// database and the catalogue.
  static Future<FlowSession> start(
    FlowSources sources, {
    bool onDevice = false,
  }) async {
    final engine = RecordingEngine();
    late Dependencies dependencies;
    final providers = await buildDependencies(
      areas: [
        (d) async => dependencies = d,
        (d) => provideUserDatabase(
          d,
          locate: _userFile,
          open: onDevice
              ? UserDatabase.openFile
              : (file) => UserDatabase(NativeDatabase(file)),
        ),
        settingsProviders,
        readingProviders,
        (d) => provideQuran(
          d,
          basePack: BasePackService(
            id: flowPackId,
            version: flowPackVersion,
            bundle: DirectoryBundle(sources.bundle),
          ),
          signatures: const SignatureNotConfigured(),
        ),
        (d) => providePackInstall(
          d,
          create: _installer,
          basePack: (id: flowPackId, version: flowPackVersion),
        ),
        (d) async {
          d.provideListenable<CatalogueRepository>(
            RemoteCatalogueRepository(
              address: sources.server.uri('/catalogue.json'),
              service: const CatalogueService(),
              openStore: () async => CatalogueStore(
                '${(await getApplicationSupportDirectory()).path}/catalogue',
              ),
              verifier: const SignatureNotConfigured(),
              policy: _http,
              acceptUnchecked: true,
            ),
          );
          provideRecitations(d);
        },
        // The wakelock plugin is the one thing userDataProviders makes.
        (d) => provideUserData(
          d,
          database: d.read<UserDatabase>(),
          settings: d.read<AppSettingsRepository>(),
          wakelock: const _NoWakelock(),
          integrityEvents: d.tryRead<PackIntegrityRepository>()?.events,
        ),
        (d) => provideAudio(d, createEngine: () => engine, locate: flowLocator),
        tafsirProviders,
        searchProviders,
        shareProviders,
        addressProviders,
        linksProviders,
      ],
    );
    // The app fetches the catalogue when the resource manager opens; here it
    // is fetched at the start, so that the recitations it lists are known.
    await dependencies.read<CatalogueRepository>().refresh();
    return FlowSession._(providers, dependencies, engine);
  }

  /// What the app provides, for `MultiProvider` as `AppStart` takes it.
  final List<SingleChildWidget> providers;

  /// The player's engine; a flow ends its tracks.
  final RecordingEngine engine;

  final Dependencies _dependencies;

  /// What the app provides as [T]; throws a [StateError] if it provides none.
  T read<T extends Object>() => _dependencies.read<T>();

  /// Closes what holds a file open, which Windows will not delete. Run it in
  /// `WidgetTester.runAsync`, after the app is gone from the tree.
  Future<void> close() async {
    if (_dependencies.tryRead<QuranTextRepository>()
        case final PackQuranTextRepository text) {
      text.close();
    }
    await _dependencies.tryRead<UserDatabase>()?.close();
  }

  static Future<File?> _userFile() async => File(
    '${(await getApplicationSupportDirectory()).path}/${UserDatabase.fileName}',
  );

  static LocalPackInstallRepository _installer({
    void Function(String packId)? onPackChanged,
    Set<String> reservedPackIds = const {},
  }) => LocalPackInstallRepository(
    openStore: InstalledPacksStore.openInApplicationSupport,
    downloads: LoopbackDownloads(
      () async => (await getApplicationSupportDirectory()).path,
    ),
    urlCheck: const HttpUrlCheck(),
    connectivity: const UnmeteredNetwork(),
    freeSpace: const RoomyDisk(),
    files: const PackFileService(),
    verifier: const LocalPackRepository(
      files: PackFileService(),
      signatures: SignatureNotConfigured(),
    ),
    policy: _http,
    acceptUnchecked: true,
    onPackChanged: onPackChanged,
    reservedPackIds: reservedPackIds,
  );
}
