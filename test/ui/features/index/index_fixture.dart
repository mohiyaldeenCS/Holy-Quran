import 'dart:io';

import 'package:holyquran/data/repositories/pack_quran_text_repository.dart';
import 'package:holyquran/data/repositories/quran_index_repository.dart';
import 'package:holyquran/domain/models/edition_map.dart';
import 'package:holyquran/domain/models/surah_info.dart';
import 'package:holyquran/utils/result.dart';

import '../../../../testing/packs/synthetic_pack.dart';
import '../../../integrity/pack_integrity_suite.dart';

// Synthetic surahs for the index, the go-to sheet and the context sheet,
// never Quran text: a handful of Arabic-script synthetic words written as
// escapes, read through the production repository. Every count a test needs
// comes from the pack, not from a constant here.

const _words = [
  '\u{646}\u{635}',
  '\u{62A}\u{62C}\u{631}\u{64A}\u{628}\u{64A}',
  '\u{643}\u{644}\u{645}',
  '\u{633}\u{637}\u{631}',
  '\u{645}\u{62B}\u{627}\u{644}',
  '\u{639}\u{64A}\u{646}\u{629}',
];

// Ayat of a surah differ in length, so no two are the same text.
String _ayah(int seed, int count) => [
  for (var k = 0; k < count; k++) _words[(seed * 5 + k * 3) % _words.length],
].join(' ');

SyntheticSurah _surah(int number, int ayat, {String? place}) => SyntheticSurah(
  name: 'Synthetic surah $number',
  revelationPlace: place,
  ayat: [
    for (var a = 1; a <= ayat; a++)
      SyntheticAyah(_ayah(number * 10 + a, 3 + a)),
  ],
);

final List<SyntheticSurah> indexSurahs = [
  _surah(1, 7, place: 'makki'),
  _surah(2, 12, place: 'madani'),
  _surah(3, 4),
];

const List<SyntheticDivision> indexDivisions = [
  SyntheticDivision('juz', 1, 1, 1),
  SyntheticDivision('juz', 2, 2, 1),
  SyntheticDivision('juz', 3, 3, 1),
  SyntheticDivision('hizb', 1, 1, 1),
  SyntheticDivision('hizb', 2, 1, 5),
  SyntheticDivision('hizb', 3, 2, 1),
  SyntheticDivision('hizb', 4, 3, 1),
  SyntheticDivision('rub', 1, 1, 1),
  SyntheticDivision('rub', 2, 1, 3),
  SyntheticDivision('rub', 3, 1, 5),
  SyntheticDivision('rub', 4, 1, 7),
  SyntheticDivision('rub', 5, 2, 1),
  SyntheticDivision('rub', 6, 2, 7),
  SyntheticDivision('rub', 7, 3, 1),
  SyntheticDivision('rub', 8, 3, 3),
  SyntheticDivision('page', 1, 1, 1),
  SyntheticDivision('page', 2, 1, 5),
  SyntheticDivision('page', 3, 2, 1),
  SyntheticDivision('page', 4, 2, 8),
  SyntheticDivision('page', 5, 3, 1),
];

/// The synthetic pack, open: its text repository and the index over it.
final class IndexFixture {
  IndexFixture._(this.pack, this.text, this.index);

  static Future<IndexFixture> load(Directory root) async {
    final built = await buildSyntheticPack(
      root,
      surahs: indexSurahs,
      divisions: indexDivisions,
      sajdas: const [],
    );
    final pack = await PackUnderTest.load(built.directory.path);
    final text = pack.openRepository();
    final index = PackQuranIndexRepository.build(
      riwaya: text.riwaya,
      surahs: _ok(await text.surahs()),
      map: _ok<EditionMap>(await text.editionMap()),
      serving: () => true,
    );
    return IndexFixture._(pack, text, _ok(index));
  }

  final PackUnderTest pack;
  final PackQuranTextRepository text;
  final PackQuranIndexRepository index;

  List<SurahInfo> get surahs => index.surahs;

  void close() => pack.close();
}

T _ok<T>(Result<T> result) => switch (result) {
  Ok(:final value) => value,
  Failure(:final error) => throw StateError('$error'),
};
