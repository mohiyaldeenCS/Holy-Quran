import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../packs/synthetic_files.dart' show syntheticArabic;
import '../packs/synthetic_pack.dart';

/// The id and version of the base pack the flows bundle.
const flowPackId = 'synthetic-text';
const flowPackVersion = 1;

/// The surah the flows read, search and play in; long enough to scroll.
const flowLongSurah = 2;
const flowLongSurahAyat = 30;

/// The search kinds the search screen offers (`SearchKinds`).
const flowSearchKinds = ['bare', 'word'];

/// Obviously synthetic Arabic-script words, written as escapes, from which
/// every ayah of the long surah is made.
const _words = [
  '\u{646}\u{635}',
  '\u{62A}\u{62C}\u{631}\u{64A}\u{628}\u{64A}',
  '\u{643}\u{644}\u{645}',
  '\u{633}\u{637}\u{631}',
  '\u{645}\u{62B}\u{627}\u{644}',
  '\u{639}\u{64A}\u{646}\u{629}',
];

// Every ayah has a text of its own, ending in a token that names its address
// and holds a letter, so that it is a word.
String _ayah(int surah, int ayah) {
  final tokens = [
    for (var k = 0; k < 4 + ayah % 5; k++) _words[(ayah + k) % 6],
  ];
  return '${tokens.join(' ')} x${surah}y$ayah';
}

/// Four, thirty and four ayat: the first and third surah hold the ayat the
/// default synthetic tafsir passages need.
final List<SyntheticSurah> flowSurahs = [
  SyntheticSurah(
    name: 'Synthetic surah one',
    basmala: syntheticArabic,
    ayat: [for (var a = 1; a <= 4; a++) SyntheticAyah(_ayah(1, a))],
  ),
  SyntheticSurah(
    name: 'Synthetic surah two',
    basmala: syntheticArabic,
    ayat: [
      for (var a = 1; a <= flowLongSurahAyat; a++) SyntheticAyah(_ayah(2, a)),
    ],
  ),
  // Texts that any trimming, normalising or re-encoding would change: edge
  // and double spaces, and an alef with hamza written decomposed and
  // precomposed. The name has such spaces and a decomposed e-acute too.
  const SyntheticSurah(
    name: ' Synthetic  surah three e\u{301} ',
    ayat: [
      SyntheticAyah(' $syntheticArabic  '),
      SyntheticAyah('\u{646}\u{635}  \u{643}\u{644}\u{645} x3y2'),
      SyntheticAyah('\u{633}\u{637}\u{631} \u{627}\u{654} x3y3'),
      SyntheticAyah('\u{633}\u{637}\u{631} \u{623} x3y4'),
    ],
  ),
];

const List<SyntheticDivision> flowDivisions = [
  SyntheticDivision('juz', 1, 1, 1),
  SyntheticDivision('juz', 2, 2, 20),
  SyntheticDivision('hizb', 1, 1, 1),
  SyntheticDivision('hizb', 2, 2, 10),
  SyntheticDivision('hizb', 3, 2, 20),
  SyntheticDivision('hizb', 4, 2, 30),
  SyntheticDivision('rub', 1, 1, 1),
  SyntheticDivision('rub', 2, 2, 5),
  SyntheticDivision('rub', 3, 2, 10),
  SyntheticDivision('rub', 4, 2, 15),
  SyntheticDivision('rub', 5, 2, 20),
  SyntheticDivision('rub', 6, 2, 25),
  SyntheticDivision('rub', 7, 2, 30),
  SyntheticDivision('rub', 8, 3, 1),
  SyntheticDivision('page', 1, 1, 1),
  SyntheticDivision('page', 2, 2, 1),
  SyntheticDivision('page', 3, 2, 7),
  SyntheticDivision('page', 4, 2, 15),
  SyntheticDivision('page', 5, 2, 23),
  SyntheticDivision('page', 6, 3, 1),
];

/// Builds the flows' base pack, a format 2 pack with the search forms of
/// [flowSearchKinds], under [root].
Future<SyntheticPack> buildFlowPack(Directory root) => buildSyntheticPack(
  root,
  surahs: flowSurahs,
  divisions: flowDivisions,
  sajdas: const [(flowLongSurah, 12)],
  formatVersion: 2,
  searchFormKinds: flowSearchKinds,
);

/// Serves the files of a directory as the bundled pack, as the app's
/// `assets/packs/<id>/<version>/` would.
final class DirectoryBundle extends CachingAssetBundle {
  DirectoryBundle(this.directory);

  static const _prefix = 'assets/packs/$flowPackId/$flowPackVersion/';

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
