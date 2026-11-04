import 'package:flutter_test/flutter_test.dart';

import 'installed_packs.dart';
import 'pack_integrity_suite.dart';
import 'recitation_pack_integrity_suite.dart';
import 'tafsir_pack_integrity_suite.dart';

// The integrity suites on real packs (D-067): those under assets/packs/, and
// the one stream B hands over with
// `flutter test test/integrity --dart-define=HOLYQURAN_PACK_DIR=<pack-id/version>`.
// A tafsir or recitation pack is checked against the text pack given with
// `--dart-define=HOLYQURAN_TEXT_PACK_DIR=<pack-id/version>`, when there is one.

const _givenPack = String.fromEnvironment('HOLYQURAN_PACK_DIR');
const _givenTextPack = String.fromEnvironment('HOLYQURAN_TEXT_PACK_DIR');

/// The suite of the kind the manifest names; the text suite when it names
/// none it can read, whose verification then fails.
void _defineSuite(String description, String directory) {
  final kind = packManifestKind(directory);
  Future<String?> textPack() async =>
      _givenTextPack.isEmpty ? null : _givenTextPack;
  switch (kind) {
    case 'tafsir':
      defineTafsirPackIntegritySuite(
        description,
        () async => directory,
        textPackDirectory: textPack,
      );
    case 'recitation':
      defineRecitationPackIntegritySuite(
        description,
        () async => directory,
        textPackDirectory: textPack,
      );
    default:
      definePackIntegritySuite(description, () async => directory);
  }
}

void main() {
  final installed = installedPackDirectories();
  if (installed.isEmpty) {
    test(
      'the packs under $installedPacksRoot/',
      () {},
      skip:
          '$installedPacksRoot/ holds no pack yet; the base pack comes from B0.2',
    );
  }
  for (final directory in installed) {
    _defineSuite('the pack $directory', directory);
  }

  if (_givenPack.isEmpty) {
    test(
      'the pack given with HOLYQURAN_PACK_DIR',
      () {},
      skip: 'no --dart-define=HOLYQURAN_PACK_DIR=<pack-id/version> was given',
    );
  } else {
    _defineSuite('the pack HOLYQURAN_PACK_DIR=$_givenPack', _givenPack);
  }
}
