import 'dart:io';
import 'dart:math' as math;

import '../../testing/packs/synthetic_pack.dart';

// A synthetic text pack with the shape of the real one, never Quran text: the
// counts of surahs, ayat and words, one long surah, and the divisions, so that
// layout, index and search cost what they would. Words are Arabic-script
// synthetic ones written as escapes, with pause marks between some of them.

/// How much of the real pack's shape to build.
enum PerfPackSize {
  /// 114 surahs and about the real counts of ayat and words, with the long
  /// surah of 286 ayat as surah 2.
  full(surahs: 114, longAyat: 286),

  /// A few surahs, for the unit tests of the harness.
  small(surahs: 4, longAyat: 24);

  const PerfPackSize({required this.surahs, required this.longAyat});

  final int surahs;
  final int longAyat;
}

/// The surah that is longest, as the reader's scroll test needs.
const perfLongSurah = 2;

const _words = [
  '\u{646}\u{635}',
  '\u{62A}\u{62C}\u{631}\u{64A}\u{628}\u{64A}',
  '\u{643}\u{644}\u{645}',
  '\u{633}\u{637}\u{631}',
  '\u{645}\u{62B}\u{627}\u{644}',
  '\u{639}\u{64A}\u{646}\u{629}',
];

const _pauseMarks = ['\u{6D6}', '\u{6D7}', '\u{6DA}'];

const _basmala = '\u{646}\u{635} \u{627}\u{641}\u{62A}\u{62A}\u{627}\u{62D}';

String _ayah(int surah, int ayah) {
  final count = 4 + (surah * 5 + ayah * 7) % 17;
  final tokens = <String>[];
  for (var k = 0; k < count; k++) {
    tokens.add(_words[(surah + ayah * 5 + k * 3) % _words.length]);
    if ((ayah + k) % 4 == 1 && k < count - 1) {
      tokens.add(_pauseMarks[(ayah + k) % _pauseMarks.length]);
    }
  }
  return tokens.join(' ');
}

int _ayat(int surah, PerfPackSize size) =>
    surah == perfLongSurah ? size.longAyat : 3 + (surah * 53) % 97;

/// The surahs of [size]; surah [perfLongSurah] is the longest.
List<SyntheticSurah> perfSurahs(PerfPackSize size) => [
  for (var s = 1; s <= size.surahs; s++)
    SyntheticSurah(
      name: 'Synthetic surah $s',
      basmala: s == 9 ? null : _basmala,
      ayat: [
        for (var a = 1; a <= _ayat(s, size); a++) SyntheticAyah(_ayah(s, a)),
      ],
    ),
];

/// [count] divisions of [kind], each starting at an even share of the ayat in
/// mushaf order.
List<SyntheticDivision> _divisions(
  String kind,
  int count,
  List<SyntheticSurah> surahs,
) {
  final starts = [
    for (final (s, surah) in surahs.indexed)
      for (var a = 1; a <= surah.ayat.length; a++) (s + 1, a),
  ];
  // A small pack has fewer ayat than the real edition has pages.
  final units = math.min(count, starts.length);
  return [
    for (var n = 1; n <= units; n++)
      SyntheticDivision(
        kind,
        n,
        starts[(n - 1) * starts.length ~/ units].$1,
        starts[(n - 1) * starts.length ~/ units].$2,
      ),
  ];
}

/// Juz, hizb, rub and page divisions in the real edition's counts.
List<SyntheticDivision> perfDivisions(List<SyntheticSurah> surahs) => [
  ..._divisions('juz', 30, surahs),
  ..._divisions('hizb', 60, surahs),
  ..._divisions('rub', 240, surahs),
  ..._divisions('page', 604, surahs),
];

/// Builds the pack of [size] under [root] and returns it, with its search
/// forms of the app's kinds.
Future<SyntheticPack> buildPerfPack(
  Directory root,
  PerfPackSize size, {
  required List<String> searchFormKinds,
}) {
  final surahs = perfSurahs(size);
  return buildSyntheticPack(
    root,
    surahs: surahs,
    divisions: perfDivisions(surahs),
    sajdas: const [],
    formatVersion: 2,
    searchFormKinds: searchFormKinds,
  );
}
