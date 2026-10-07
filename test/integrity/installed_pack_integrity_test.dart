import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'pack_integrity_suite.dart';

// The integrity suite on real packs (D-067): those under assets/packs/, and
// the one stream B hands over with
// `flutter test test/integrity --dart-define=HOLYQURAN_PACK_DIR=<pack-id/version>`.

const _packsRoot = 'assets/packs';
const _givenPack = String.fromEnvironment('HOLYQURAN_PACK_DIR');

/// Every directory under [_packsRoot] that holds a `manifest.json`.
List<String> _installedPacks() {
  final root = Directory(_packsRoot);
  if (!root.existsSync()) return const [];
  return [
    for (final file in root.listSync(recursive: true).whereType<File>())
      if (file.uri.pathSegments.last == 'manifest.json')
        file.parent.path.replaceAll(r'\', '/'),
  ]..sort();
}

void main() {
  final installed = _installedPacks();
  if (installed.isEmpty) {
    test(
      'the packs under $_packsRoot/',
      () {},
      skip: '$_packsRoot/ holds no pack yet; the base pack comes from B0.2',
    );
  }
  for (final directory in installed) {
    definePackIntegritySuite('the pack $directory', () async => directory);
  }

  if (_givenPack.isEmpty) {
    test(
      'the pack given with HOLYQURAN_PACK_DIR',
      () {},
      skip: 'no --dart-define=HOLYQURAN_PACK_DIR=<pack-id/version> was given',
    );
  } else {
    definePackIntegritySuite(
      'the pack HOLYQURAN_PACK_DIR=$_givenPack',
      () async => _givenPack,
    );
  }
}
