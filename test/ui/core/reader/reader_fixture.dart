import 'dart:io';

import 'package:holyquran/data/repositories/quran_text_repository.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/ui/core/reader/reader_anchors.dart';
import 'package:holyquran/ui/core/reader/surah_text.dart';
import 'package:holyquran/utils/result.dart';

import '../../../../testing/packs/synthetic_pack.dart';
import '../../../integrity/pack_integrity_suite.dart';

// Synthetic surahs for the surah-mode engine, never Quran text: a handful of
// Arabic-script synthetic words, written as escapes, with pause marks between
// words and a sajda sign, so that lines break in right-to-left text the way
// the real text breaks. Read through the production repository.

const _words = [
  '\u{646}\u{635}',
  '\u{62A}\u{62C}\u{631}\u{64A}\u{628}\u{64A}',
  '\u{643}\u{644}\u{645}',
  '\u{633}\u{637}\u{631}',
  '\u{645}\u{62B}\u{627}\u{644}',
  '\u{639}\u{64A}\u{646}\u{629}',
];

const _pauseMarks = ['\u{6D6}', '\u{6D7}', '\u{6DA}'];

const sajdaSign = '\u{6E9}';

/// A word longer than any line at four times the text size.
final overwideWord = _words[1] * 6;

/// The long surah's number, its ayat, and the ayah that carries a sajda.
const longSurah = 2;
const longSurahAyat = 40;
const sajdaAyah = 12;

/// The surah holding [overwideWord].
const overwideSurah = 3;

/// An ayah of [count] synthetic words, a pause mark after some of them and,
/// when [sajda], the sajda sign at its end.
String _ayah(int seed, int count, {bool sajda = false}) {
  final tokens = <String>[];
  for (var k = 0; k < count; k++) {
    tokens.add(_words[(seed * 5 + k * 3) % _words.length]);
    if ((seed + k) % 4 == 1 && k < count - 1) {
      tokens.add(_pauseMarks[(seed + k) % _pauseMarks.length]);
    }
  }
  if (sajda) tokens.add(sajdaSign);
  return tokens.join(' ');
}

const _basmala = '\u{646}\u{635} \u{627}\u{641}\u{62A}\u{62A}\u{627}\u{62D}';

SyntheticSurah _short(int number, {String? basmala = _basmala}) =>
    SyntheticSurah(
      name: 'Synthetic surah $number',
      basmala: basmala,
      ayat: [SyntheticAyah(_ayah(number, 5))],
    );

final List<SyntheticSurah> readerSurahs = [
  _short(1),
  SyntheticSurah(
    name: 'Synthetic long surah',
    basmala: _basmala,
    ayat: [
      for (var a = 1; a <= longSurahAyat; a++)
        SyntheticAyah(
          _ayah(a, a % 7 == 0 ? 1 : 3 + (a * 7) % 11, sajda: a == sajdaAyah),
        ),
    ],
  ),
  SyntheticSurah(
    name: 'Synthetic overwide surah',
    basmala: _basmala,
    ayat: [
      SyntheticAyah(
        '${_words[0]} $overwideWord ${_pauseMarks[0]} ${_words[2]}',
      ),
      SyntheticAyah(_ayah(3, 6)),
    ],
  ),
  for (var s = 4; s <= 8; s++) _short(s),
  _short(9, basmala: null),
];

const List<SyntheticDivision> readerDivisions = [
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
  SyntheticDivision('rub', 8, 2, 35),
  SyntheticDivision('page', 1, 1, 1),
  SyntheticDivision('page', 2, 2, 1),
  SyntheticDivision('page', 3, 2, 7),
  SyntheticDivision('page', 4, 2, 15),
  SyntheticDivision('page', 5, 2, 23),
  SyntheticDivision('page', 6, 2, 31),
  SyntheticDivision('page', 7, 3, 1),
];

/// The synthetic pack, open, with every surah read as the reader gets it.
final class ReaderFixture {
  ReaderFixture._(this.pack, this.surahs);

  static Future<ReaderFixture> load(Directory root) async {
    final built = await buildSyntheticPack(
      root,
      surahs: readerSurahs,
      divisions: readerDivisions,
      sajdas: const [(longSurah, sajdaAyah)],
    );
    final pack = await PackUnderTest.load(built.directory.path);
    final repository = pack.openRepository();
    final map = _value(await repository.editionMap());
    final surahs = <int, SurahText>{};
    for (final info in _value(await repository.surahs())) {
      surahs[info.number] = await _surahText(
        repository,
        info.number,
        info.ayahCount,
        pageStarts: pageStartsIn(map, repository.riwaya, info.number),
        marginMarks: marginMarksIn(map, repository.riwaya, info.number),
      );
    }
    return ReaderFixture._(pack, surahs);
  }

  final PackUnderTest pack;
  final Map<int, SurahText> surahs;

  void close() => pack.close();
}

Future<SurahText> _surahText(
  QuranTextRepository repository,
  int surah,
  int ayahCount, {
  required Map<int, int> pageStarts,
  required List<MarginMark> marginMarks,
}) async {
  final ayat = <AyahText>[];
  for (var ayah = 1; ayah <= ayahCount; ayah++) {
    final address = QuranAddress(repository.riwaya, surah, ayah);
    ayat.add(
      AyahText(
        text: _value(await repository.ayahText(address)),
        words: _value(await repository.words(address)),
        marks: _value(await repository.marks(address)),
      ),
    );
  }
  return SurahText(
    riwaya: repository.riwaya,
    surah: surah,
    ayat: ayat,
    basmala: _value(await repository.basmala(surah)),
    pageStarts: pageStarts,
    marginMarks: marginMarks,
  );
}

T _value<T>(Result<T> result) => switch (result) {
  Ok(:final value) => value,
  Failure(:final error) => throw StateError('$error'),
};
