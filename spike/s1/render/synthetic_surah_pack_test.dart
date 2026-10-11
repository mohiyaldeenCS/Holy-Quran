import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/data/repositories/pack_quran_text_repository.dart';
import 'package:holyquran/domain/models/mark_span.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/word_span.dart';
import 'package:holyquran/utils/result.dart';

import '../../../test/integrity/pack_integrity_suite.dart';
import '../../../testing/packs/raw_pack.dart';
import 'spike_surah_text.dart';
import 'surah_paragraph.dart';
import 'synthetic_surah_pack.dart';

// Every value is Arabic-script nonsense from the generator, compared by
// digest, offset and code point only.

/// The surah digests of the default synthetic pack, computed from the
/// generator as it was before marks existed (base of M0.4 task A).
const _defaultDigests = {
  syntheticLongSurah:
      '2b95ac539efda80782e12373484779fa8bd28c84c91e76ac1b4e9316f6bd849c',
  syntheticShortSurah:
      '5582b4de50c2762cfe5904e84952c5886bc5ce7f3f36f7543972e95b05db18cb',
};

String _directoryOf(Directory root) => '${root.path}/spike-tanzil-uthmani/1';

String _digestOf(RawPack raw, int surah) => surahDigest([
  for (final (_, bytes) in raw.ayat(surah)) bytes,
], basmala: raw.surahs()[surah - 1].basmala);

void main() {
  late Directory root;
  late PackQuranTextRepository plain;
  late PackQuranTextRepository marked;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('synthetic_surah_pack');
    plain = await openSyntheticSpikePack(Directory('${root.path}/plain'));
    marked = await openSyntheticSpikePack(
      Directory('${root.path}/marked'),
      withMarks: true,
    );
  });
  tearDownAll(() async {
    plain.close();
    marked.close();
    await root.delete(recursive: true);
  });

  definePackIntegritySuite(
    'the synthetic pack with marks',
    () async => _directoryOf(Directory('${root.path}/marked')),
  );

  test('without marks, both surahs are the strings of before marks', () {
    final raw = RawPack.open(
      File('${_directoryOf(Directory('${root.path}/plain'))}/text.sqlite'),
    );
    addTearDown(raw.close);
    for (final MapEntry(key: surah, value: digest) in _defaultDigests.entries) {
      expect(_digestOf(raw, surah), digest, reason: 'surah $surah');
      for (final (ayah, _) in raw.ayat(surah)) {
        expect(raw.marks(surah, ayah), isEmpty);
      }
    }
  });

  test('with marks, the short surah is unchanged and the long one keeps '
      'its words, with one-code-point marks U+06D6 to U+06DC around them', () {
    final rawPlain = RawPack.open(
      File('${_directoryOf(Directory('${root.path}/plain'))}/text.sqlite'),
    );
    final rawMarked = RawPack.open(
      File('${_directoryOf(Directory('${root.path}/marked'))}/text.sqlite'),
    );
    addTearDown(rawPlain.close);
    addTearDown(rawMarked.close);
    expect(
      _digestOf(rawMarked, syntheticShortSurah),
      _defaultDigests[syntheticShortSurah],
    );
    expect(
      rawMarked.surahs()[syntheticLongSurah - 1].basmala,
      rawPlain.surahs()[syntheticLongSurah - 1].basmala,
    );
    final plainAyat = rawPlain.ayat(syntheticLongSurah);
    final markedAyat = rawMarked.ayat(syntheticLongSurah);
    expect(markedAyat, hasLength(syntheticLongAyat));
    var words = 0;
    var marks = 0;
    var beforeFirst = 0;
    var atEnd = 0;
    for (var a = 0; a < syntheticLongAyat; a++) {
      final ayah = a + 1;
      final before = utf8.decode(plainAyat[a].$2);
      final after = utf8.decode(markedAyat[a].$2);
      List<int> unitsOf(String text, int start, int end) =>
          text.codeUnits.sublist(start, end);
      final plainWords = rawPlain.words(syntheticLongSurah, ayah);
      final markedWords = rawMarked.words(syntheticLongSurah, ayah);
      expect(
        [for (final (_, s, e) in markedWords) unitsOf(after, s, e)],
        [for (final (_, s, e) in plainWords) unitsOf(before, s, e)],
        reason: 'ayah $ayah words',
      );
      final ayahMarks = rawMarked.marks(syntheticLongSurah, ayah);
      for (final (_, afterWord, start, end) in ayahMarks) {
        expect(end - start, 1);
        expect(after.codeUnitAt(start), inInclusiveRange(0x06D6, 0x06DC));
        if (afterWord == 0) beforeFirst++;
        if (end == after.length) atEnd++;
      }
      words += markedWords.length;
      marks += ayahMarks.length;
    }
    expect(beforeFirst, greaterThanOrEqualTo(1));
    expect(atEnd, greaterThanOrEqualTo(1));
    expect(marks / words, inInclusiveRange(1 / 12, 1 / 5));
  });

  test(
    'SpikeSurahText.marks are the repository\'s, one list per ayah',
    () async {
      final surah = await readSpikeSurahText(marked, syntheticLongSurah);
      expect(surah.marks, hasLength(syntheticLongAyat));
      for (var a = 0; a < syntheticLongAyat; a++) {
        final address = QuranAddress(marked.riwaya, syntheticLongSurah, a + 1);
        expect(
          surah.marks[a],
          (await marked.marks(address) as Ok<List<MarkSpan>>).value,
        );
      }
      final read = await readSyntheticSurahs(
        Directory('${root.path}/read'),
        withMarks: true,
      );
      addTearDown(read.pack.close);
      expect(read.long.marks.expand((m) => m), isNotEmpty);
      expect(read.short.marks.expand((m) => m), isEmpty);
    },
  );

  test('SpikeSurahText takes no marks as none per ayah, and refuses another '
      'number of lists', () {
    SpikeSurahText build({List<List<MarkSpan>>? marks}) => SpikeSurahText(
      firstAyah: QuranAddress('hafs', 1, 1),
      ayat: const [PackText.fromPack('a'), PackText.fromPack('b')],
      words: const [
        [WordSpan(number: 1, start: 0, end: 1)],
        [WordSpan(number: 1, start: 0, end: 1)],
      ],
      marks: marks,
      basmala: null,
      pageStarts: const {},
    );
    expect(build().marks, [isEmpty, isEmpty]);
    expect(() => build(marks: [[]]), throwsArgumentError);
  });

  test(
    'a block may start at a stored mark start, not inside a token',
    () async {
      final surah = await readSpikeSurahText(marked, syntheticLongSurah);
      final index = surah.marks.indexWhere(
        (marks) => marks.any((m) => m.afterWord > 0),
      );
      final mark = surah.marks[index].firstWhere((m) => m.afterWord > 0);
      final ayah = QuranAddress(marked.riwaya, syntheticLongSurah, index + 1);
      SurahBlockContent startingAt(int offset, {bool withMarks = true}) =>
          SurahBlockContent(
            firstAyah: ayah,
            ayat: [surah.ayat[index]],
            words: [surah.words[index]],
            marks: withMarks ? [surah.marks[index]] : null,
            startOffset: offset,
          );
      expect(startingAt(mark.start).startOffset, mark.start);
      expect(
        () => startingAt(mark.start, withMarks: false),
        throwsArgumentError,
      );
      expect(() => startingAt(mark.start + 1), throwsArgumentError);
      expect(startingAt(mark.start).sameAs(startingAt(mark.start)), isTrue);
      expect(
        () => SurahBlockContent(
          firstAyah: ayah,
          ayat: [surah.ayat[index]],
          words: [surah.words[index]],
          marks: const [],
        ),
        throwsArgumentError,
      );
    },
  );
}
