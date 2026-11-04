import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:holyquran/config/dependencies.dart';
import 'package:holyquran/config/providers/address_providers.dart';
import 'package:holyquran/config/providers/links_providers.dart';
import 'package:holyquran/config/providers/quran_providers.dart';
import 'package:holyquran/config/providers/reading_providers.dart';
import 'package:holyquran/config/providers/search_providers.dart';
import 'package:holyquran/config/providers/settings_providers.dart';
import 'package:holyquran/config/providers/user_data_providers.dart';
import 'package:holyquran/config/providers/user_database_providers.dart';
import 'package:holyquran/data/repositories/app_settings_repository.dart';
import 'package:holyquran/data/repositories/pack_quran_text_repository.dart';
import 'package:holyquran/data/repositories/quran_text_repository.dart';
import 'package:holyquran/data/repositories/reading_position_repository.dart';
import 'package:holyquran/data/services/base_pack_service.dart';
import 'package:holyquran/data/services/manifest_signature.dart';
import 'package:holyquran/data/services/user_database.dart';
import 'package:holyquran/ui/features/search/view_models/search_view_model.dart';
import 'package:provider/single_child_widget.dart';

import 'perf_pack.dart';

const _packId = 'synthetic-text';

/// Serves the files of [directory] as the bundled pack, as the app's asset
/// bundle serves `assets/packs/<id>/<version>/` (D-030).
final class _DirectoryBundle extends CachingAssetBundle {
  _DirectoryBundle(this.directory);

  final Directory directory;

  @override
  Future<ByteData> load(String key) async {
    final file = File('${directory.path}/${key.split('/').last}');
    if (!file.existsSync()) throw FlutterError('Unable to load asset: "$key".');
    return ByteData.sublistView(await file.readAsBytes());
  }
}

/// One start of the app: what the widget tree is given, and the objects the
/// harness reaches into.
final class PerfStart {
  PerfStart._({
    required this.providers,
    required this.settings,
    required this.positions,
    required this._text,
    required this._database,
  });

  /// As `buildDependencies` returns them.
  final List<SingleChildWidget> providers;
  final AppSettingsRepository settings;
  final ReadingPositionRepository? positions;
  final QuranTextRepository? _text;
  final UserDatabase _database;

  /// Closes the pack and the user database, which Windows keeps open.
  Future<void> close() async {
    (_text as PackQuranTextRepository?)?.close();
    await _database.close();
  }
}

/// The app's start over a synthetic pack of the real pack's shape, with the
/// areas the screens under measurement read, set up in the app's own order by
/// its own code. The audio, download and catalogue areas, which need plugins
/// and a network, and the tafsir area, which needs an installed book, are
/// left out.
final class PerfApp {
  PerfApp._(this._support, this._bundle, this.size, this.packReused);

  final Directory _support;
  final Directory _bundle;
  final PerfPackSize size;

  /// Whether the pack was built by an earlier launch of the install, as
  /// every start but the first finds it.
  final bool packReused;

  /// Opens the harness over the application support folder [support], where
  /// an earlier run may have built the pack.
  ///
  /// A device has no repository to read the pinned font from, so it passes
  /// [fontBytes] from its bundle.
  static Future<PerfApp> open({
    required PerfPackSize size,
    required Directory support,
    Uint8List? fontBytes,
  }) async {
    final root = Directory('${support.path}/perf_bundle/${size.name}');
    final bundle = Directory('${root.path}/$_packId/1');
    final reused = File('${bundle.path}/manifest.json').existsSync();
    if (!reused) {
      await buildPerfPack(
        root,
        size,
        searchFormKinds: SearchKinds.all,
        fontBytes: fontBytes,
      );
    }
    return PerfApp._(support, bundle, size, reused);
  }

  /// Sets the app up as `main` does before the first frame.
  Future<PerfStart> start() async {
    QuranTextRepository? text;
    late final UserDatabase database;
    late final AppSettingsRepository settings;
    ReadingPositionRepository? positions;
    final providers = await buildDependencies(
      areas: [
        userDatabaseProviders,
        settingsProviders,
        readingProviders,
        (dependencies) => provideQuran(
          dependencies,
          basePack: BasePackService(
            id: _packId,
            version: 1,
            bundle: _DirectoryBundle(_bundle),
            supportDirectory: () async => _support,
          ),
          signatures: const SignatureNotConfigured(),
        ),
        userDataProviders,
        searchProviders,
        addressProviders,
        linksProviders,
        (dependencies) async {
          text = dependencies.tryRead<QuranTextRepository>();
          database = dependencies.read<UserDatabase>();
          settings = dependencies.read<AppSettingsRepository>();
          positions = dependencies.tryRead<ReadingPositionRepository>();
        },
      ],
    );
    return PerfStart._(
      providers: providers,
      settings: settings,
      positions: positions,
      text: text,
      database: database,
    );
  }
}
