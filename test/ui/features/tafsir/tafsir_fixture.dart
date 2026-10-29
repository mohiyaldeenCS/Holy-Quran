import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/data/models/pack_manifest_json.dart';
import 'package:holyquran/data/repositories/local_pack_repository.dart';
import 'package:holyquran/data/repositories/pack_quran_text_repository.dart';
import 'package:holyquran/data/repositories/tafsir_repository.dart';
import 'package:holyquran/data/services/daos/settings_dao.dart';
import 'package:holyquran/data/services/manifest_signature.dart';
import 'package:holyquran/data/services/pack_file_service.dart';
import 'package:holyquran/data/services/user_database.dart';
import 'package:holyquran/domain/models/installed_pack.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/utils/result.dart';

import '../../../../testing/fakes/fake_pack_install_repository.dart';
import '../../../../testing/fakes/fake_pack_integrity_repository.dart';
import '../../../../testing/fakes/fake_quran_index_repository.dart';
import '../../../../testing/packs/synthetic_pack.dart';
import '../../../../testing/packs/synthetic_tafsir_pack.dart';
import '../../../integrity/pack_integrity_suite.dart';

/// The synthetic text pack (surahs of 4, 3 and 1 ayat) and a synthetic
/// tafsir book over it, read by the real repositories. Every text in them is
/// synthetic.
final class TafsirFixture {
  TafsirFixture._({
    required this.root,
    required this.textPack,
    required this.quran,
    required this.installs,
    required this.tafsirs,
    required this.database,
    required this.integrity,
  });

  /// The id of the book [open] installs.
  static const bookId = 'synthetic-tafsir';

  final Directory root;
  final PackUnderTest textPack;
  final PackQuranTextRepository quran;
  final FakePackInstallRepository installs;
  final LocalTafsirRepository tafsirs;
  final UserDatabase database;
  final FakePackIntegrityRepository integrity;
  final books = <String, SyntheticTafsirPack>{};

  /// Builds the text pack and the repositories, installs the default book
  /// unless [install] is false, and reads it once, so that later reads of it
  /// are not delayed by the pack's check.
  static Future<TafsirFixture> open({bool install = true}) async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final root = await Directory.systemTemp.createTemp('tafsir_ui_test');
    final built = await buildSyntheticPack(Directory('${root.path}/text'));
    final textPack = await PackUnderTest.load(built.directory.path);
    final database = UserDatabase(NativeDatabase.memory());
    final installs = FakePackInstallRepository();
    final integrity = FakePackIntegrityRepository();
    final tafsirs = switch (await LocalTafsirRepository.load(
      installs: installs,
      integrity: integrity,
      verifier: const LocalPackRepository(
        files: PackFileService(),
        signatures: SignatureNotConfigured(),
      ),
      structure: FakeQuranIndexRepository.synthetic(),
      settings: SettingsDao(database),
    )) {
      Ok(:final value) => value,
      Failure(:final error) => throw TestFailure('$error'),
    };
    final fixture = TafsirFixture._(
      root: root,
      textPack: textPack,
      quran: textPack.openRepository(),
      installs: installs,
      tafsirs: tafsirs,
      database: database,
      integrity: integrity,
    );
    if (install) await fixture.install();
    return fixture;
  }

  /// Installs another book, or the default one, and reads it once. With
  /// [corrupt] a byte is added to its file first, so that its hash no longer
  /// matches, and it is not read.
  Future<InstalledPack> install({
    String id = bookId,
    SyntheticBook book = defaultSyntheticBook,
    List<SyntheticPassage> passages = defaultSyntheticPassages,
    bool corrupt = false,
  }) async {
    final pack = await buildSyntheticTafsirPack(
      root,
      id: id,
      book: book,
      passages: passages,
    );
    books[id] = pack;
    if (corrupt) await pack.file.writeAsBytes([0], mode: FileMode.append);
    final installed = InstalledPack(
      manifest: switch (parsePackManifest(
        utf8.encode(jsonEncode(pack.manifest)),
        pack: pack.directory.path,
      )) {
        Ok(:final value) => value,
        Failure(:final error) => throw TestFailure('$error'),
      },
      directory: pack.directory.path,
      previousVersion: null,
    );
    installs.installed = [...installs.installed, installed];
    if (!corrupt) {
      await tafsirs.positionAt(id, QuranAddress(quran.riwaya, 1, 1));
    }
    return installed;
  }

  Future<void> close() async {
    tafsirs.dispose();
    integrity.dispose();
    installs.dispose();
    textPack.close();
    await database.close();
    await root.delete(recursive: true);
  }
}
