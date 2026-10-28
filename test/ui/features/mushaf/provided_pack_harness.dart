import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:holyquran/config/dependencies.dart';
import 'package:holyquran/config/providers/quran_providers.dart';
import 'package:holyquran/data/repositories/pack_integrity_repository.dart';
import 'package:holyquran/data/repositories/pack_quran_text_repository.dart';
import 'package:holyquran/data/repositories/quran_index_repository.dart';
import 'package:holyquran/data/repositories/quran_text_repository.dart';
import 'package:holyquran/data/services/base_pack_service.dart';
import 'package:holyquran/data/services/manifest_signature.dart';
import 'package:holyquran/ui/features/mushaf/view_models/mushaf_view_model.dart';

import '../../../../testing/packs/synthetic_pack.dart';
import '../../core/reader/reader_fixture.dart';

/// Serves the files of [directory] as the bundled pack synthetic-text/1.
final class _DirectoryBundle extends CachingAssetBundle {
  _DirectoryBundle(this.directory);

  static const _prefix = 'assets/packs/${ProvidedPack.packId}/1/';

  final Directory directory;

  @override
  Future<ByteData> load(String key) async {
    final file = File('${directory.path}/${key.substring(_prefix.length)}');
    if (!key.startsWith(_prefix) || !file.existsSync()) {
      throw FlutterError('Unable to load asset: "$key".');
    }
    return ByteData.sublistView(await file.readAsBytes());
  }
}

/// The Quran area as the app sets it up at start (`provideQuran`), over a
/// bundled synthetic pack of the reader's surahs built with [fault], and an
/// application support folder that did not exist before. Nothing else is
/// provided: no network area, no user data.
final class ProvidedPack {
  ProvidedPack._({
    required this.support,
    required this.integrity,
    this.text,
    this.index,
  });

  static const packId = 'synthetic-text';

  /// Sets the area up. Run it in `WidgetTester.runAsync`.
  static Future<ProvidedPack> load(
    Directory root, {
    SyntheticFault? fault,
  }) async {
    final built = await buildSyntheticPack(
      Directory('${root.path}/bundle'),
      surahs: readerSurahs,
      divisions: readerDivisions,
      sajdas: const [(longSurah, sajdaAyah)],
      fault: fault,
    );
    final support = Directory('${root.path}/support');
    final basePack = BasePackService(
      id: packId,
      version: 1,
      bundle: _DirectoryBundle(built.directory),
      supportDirectory: support.create,
    );
    PackIntegrityRepository? integrity;
    QuranTextRepository? text;
    QuranIndexRepository? index;
    await buildDependencies(
      areas: [
        (dependencies) => provideQuran(
          dependencies,
          basePack: basePack,
          signatures: const SignatureNotConfigured(),
        ),
        (dependencies) async {
          integrity = dependencies.read<PackIntegrityRepository>();
          // A base pack that fails its check provides no text.
          try {
            text = dependencies.read<QuranTextRepository>();
            index = dependencies.read<QuranIndexRepository>();
          } on StateError {
            return;
          }
        },
      ],
    );
    return ProvidedPack._(
      support: support,
      integrity: integrity!,
      text: text,
      index: index,
    );
  }

  final Directory support;
  final PackIntegrityRepository integrity;
  final QuranTextRepository? text;
  final QuranIndexRepository? index;

  /// The reader's view model over what the area provided; with no text, one
  /// the app builds before the base pack is ready.
  MushafViewModel viewModel() =>
      MushafViewModel(text: text, index: index, integrity: integrity);

  /// Closes the pack file, which Windows keeps open, before its folder goes.
  void close() {
    (text as PackQuranTextRepository?)?.close();
    if (integrity case final ChangeNotifier notifier) notifier.dispose();
  }
}
