import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/quran_address.dart';

import '../../../testing/packs/synthetic_pack.dart' show amiriQuranFontPath;
import '../render/synthetic_surah_pack.dart';
import '../text/gibberish.dart';
import '../text/spike_pack_writer.dart';
import '../text/tanzil_fixture.dart';
import '../text/tanzil_xml.dart';
import 'text_checks.dart';
import 'unicode_categories.dart';

// Every text here is synthetic: Arabic-script nonsense, and tokens made of
// single code points named by number.

/// A spike pack of [suras] under [root], verified and opened.
Future<({String directory, TextPackMeasurement measurement})> _measure(
  Directory root,
  List<FixtureSura> suras, {
  List<int>? surahNumbers,
}) async {
  final bytes = tanzilFixtureXml(suras);
  final xml = readTanzilXml(bytes);
  final font = File(amiriQuranFontPath).readAsBytesSync();
  final directory = await writeSpikePack(
    root,
    surahs: spikeSurahsOf(xml),
    fontSha256: sha256.convert(font).toString(),
    source: (
      bytes: bytes,
      url: 'https://example.invalid/synthetic.xml',
      version: tanzilUthmaniVersion,
      fetchedOn: '2026-01-01',
      notice: xml.notice,
    ),
  );
  final opened = await openVerifiedPack(directory);
  final measurement = TextPackMeasurement();
  try {
    await measurement.run(
      verified: opened.verified,
      text: opened.text,
      ttf: font,
      surahNumbers: surahNumbers,
      widths: const [360],
      scales: const [1],
    );
  } finally {
    opened.text.close();
  }
  return (directory: directory, measurement: measurement);
}

void main() {
  late Directory root;
  setUp(() async => root = await Directory.systemTemp.createTemp('s1_measure'));
  tearDown(() => root.delete(recursive: true));

  test('a word with no letter is one whose code points are all known and '
      'none a letter', () {
    expect(isLetterless([0x06DE]), isTrue);
    expect(isLetterless([0x0651, 0x064E]), isTrue);
    expect(isLetterless(const []), isTrue);
    expect(isLetterless([0x0628, 0x0651]), isFalse);
    expect(isLetterless([0x0640]), isFalse, reason: 'tatweel is Lm');
    expect(isLetterless([0x06DE, 0x1F600]), isFalse, reason: 'unclassified');
  });

  test('the category table agrees with what the generator writes', () {
    for (final c in SyntheticArabicScript.letters) {
      expect(generalCategory(c), 'Lo', reason: codePointName(c));
    }
    for (final c in [...SyntheticArabicScript.vowels, 0x0651]) {
      expect(generalCategory(c), 'Mn', reason: codePointName(c));
    }
    expect(generalCategory(0x0020), 'Zs');
    expect(generalCategory(0x06DE), 'So');
    expect(generalCategory(0x0661), 'Nd');
    expect(generalCategory(0x0640), 'Lm');
    expect(generalCategory(0x0041), isNull, reason: 'outside the table');
    expect(generalCategory(0x061E), 'Po');
    expect(generalCategory(0x0890), 'Cf');
    expect(generalCategory(0x088F), isNull, reason: 'unassigned');
    expect(codePointName(0x6DE), 'U+06DE');
    expect(codePointName(0x1F600), 'U+1F600');
  });

  test('a clean nonsense pack has no problem, and its results are ASCII '
      'numbers, digests, code points and addresses', () async {
    final nonsense = SyntheticArabicScript(3);
    final run = await _measure(root, [
      (
        name: nonsense.word(),
        bismillah: nonsense.phrase(4),
        ayat: [for (var a = 0; a < 12; a++) nonsense.phrase(5 + a)],
      ),
      (name: nonsense.word(), bismillah: null, ayat: [nonsense.phrase(3)]),
    ]);
    final m = run.measurement;
    expect(m.problemCounts.values, everyElement(0));
    final results = m.results;
    final encoded = jsonEncode(results);
    expect(encoded.runes.where((c) => c > 0x7E), isEmpty);
    final cmap = results['cmap']! as Map<String, Object?>;
    expect(cmap['fontIsThePacksFont'], isTrue);
    expect(cmap['missing'], isEmpty);
    expect(
      (cmap['used']! as Map<String, Object?>).keys,
      everyElement(matches(RegExp(r'^U\+[0-9A-F]{4,6}$'))),
    );
    final tokens = results['markOnlyTokens']! as Map<String, Object?>;
    expect(tokens['noLetter'], 0);
    expect(tokens['unclassifiedTokens'], 0);
    final surahs = results['surahs']! as List<Map<String, Object?>>;
    expect([for (final s in surahs) s['surah']], [1, 2]);
    final runs = surahs.first['runs']! as List<Map<String, Object?>>;
    final first = runs.single;
    expect(first['width'], 360);
    expect(first['lines'], greaterThan(5));
    expect(first['slicedAyat'], 12);
    expect(first['fingerprint'], matches(RegExp(r'^[0-9a-f]{64}$')));
    final ink = first['ink']! as Map<String, Object?>;
    expect(ink['lines'], first['lines']);
    expect(ink['edges'], hasLength((first['lines']! as int) - 1));
    expect(ink.keys, containsAll(['linesLeaving', 'maxReach', 'ms']));
    final stretch = first['stretch']! as Map<String, Object?>;
    expect(stretch['max'], greaterThanOrEqualTo(stretch['p99']! as double));
    expect(
      (first['v2']! as Map<String, Object?>)['sameLineStartsAsV1'],
      isTrue,
      reason: 'a page starts at ayah 11 (one every 10 ayat)',
    );
    final second = surahs.last['runs']! as List<Map<String, Object?>>;
    expect(second.single['v2'], isNull, reason: 'one ayah, no page inside');
    expect(results['summary'], contains('360/1.0x'));
    final summary = summaryLines(results);
    expect(summary.length, lessThan(150));
    expect(summary.join('\n').runes.where((c) => c > 0x7E), isEmpty);
    expect(summary, contains(startsWith('360/1.0x: ')));
  });

  test('a code point the font lacks and tokens without a letter are found, '
      'by code point and address', () async {
    final nonsense = SyntheticArabicScript(5);
    final tokens = [
      '\u06DE',
      '\u0651\u064E',
      '\u064E\u0651',
      '\u0661\u0662',
      '\u{1F600}',
    ];
    final run = await _measure(root, [
      (
        name: nonsense.word(),
        bismillah: null,
        ayat: [
          nonsense.phrase(3),
          [nonsense.word(), ...tokens, nonsense.word()].join(' '),
        ],
      ),
    ]);
    final m = run.measurement;
    expect(m.problemCounts[ProblemKind.cmap], 1);
    expect(m.problems[ProblemKind.cmap], [
      'U+1F600 is not in the font: 1 times, first at hafs:1:2',
    ]);
    final cmap = m.results['cmap']! as Map<String, Object?>;
    expect(cmap['missing'], [
      {
        'codePoint': 'U+1F600',
        'count': 1,
        'firstAt': ['hafs:1:2'],
      },
    ]);
    final found = m.results['markOnlyTokens']! as Map<String, Object?>;
    expect(found['tokens'], 3 + 2 + tokens.length);
    expect(found['noLetter'], 4);
    expect(found['marksOnly'], 2);
    expect(found['unclassifiedTokens'], 1);
    expect(found['unclassifiedCodePoints'], {'U+1F600': 1});
    expect(found['groups'], [
      {
        'codePoints': ['U+064E', 'U+0651'],
        'categories': ['Mn', 'Mn'],
        'count': 2,
        'addresses': ['hafs:1:2:3', 'hafs:1:2:4'],
      },
      {
        'codePoints': ['U+0661', 'U+0662'],
        'categories': ['Nd', 'Nd'],
        'count': 1,
        'addresses': ['hafs:1:2:5'],
      },
      {
        'codePoints': ['U+06DE'],
        'categories': ['So'],
        'count': 1,
        'addresses': ['hafs:1:2:2'],
      },
    ]);
    expect(jsonEncode(m.results).runes.where((c) => c > 0x7E), isEmpty);
    final layout =
        ((m.results['surahs']! as List<Map<String, Object?>>).single['runs']!
                as List<Map<String, Object?>>)
            .single;
    final hit = layout['hit']! as Map<String, Object?>;
    expect(hit['letterlessWords'], 4, reason: 'U+1F600 is unclassified');
    expect(
      m.problemCounts[ProblemKind.hitRoundTrip],
      hit['letterProblems'],
      reason: 'only words with a letter fail',
    );
    expect(
      hit['letterlessKinds'],
      {'noBox': 2},
      reason: 'combining marks alone get no box (Flutter 3.44.7)',
    );
    expect(hit['letterlessExamples'], ['hafs:1:2:3', 'hafs:1:2:4']);
  });

  test('hit problems split into words without a letter, words beside one '
      'that starts a line, and the rest', () {
    QuranAddress at(int ayah, int word) => QuranAddress('hafs', 1, ayah, word);
    final split = splitHitProblems(
      [
        '${at(1, 3)}: no box',
        '${at(1, 2)}: empty',
        '${at(1, 2)}: centre hits null',
        '${at(2, 1)}: centre hits ${at(2, 2)}',
        '${at(2, 4)}: outside its line band',
      ],
      {at(1, 3), at(2, 2)},
      {at(1, 3)},
    );
    expect(split.letter, [
      '${at(2, 1)}: centre hits ${at(2, 2)}',
      '${at(2, 4)}: outside its line band',
    ]);
    expect(split.json['letterProblems'], 4);
    expect(split.json['hitBesideLineStartMark'], 2);
    expect(split.json['hitBesideLineStartMarkWords'], 1);
    expect(split.json['hitBesideLineStartMarkKinds'], {
      'empty': 1,
      'centreHitsNull': 1,
    });
    expect(split.json['unexplainedKinds'], {
      'centreHitsOther': 1,
      'outsideBand': 1,
    });
    expect(split.json['unexplained'], [
      'hafs:1:2:1 centreHitsOther',
      'hafs:1:2:4 outsideBand',
    ]);
    expect(split.json['letterWordsBesideLetterless'], 2);
    expect(split.json['letterHitsLetterless'], 1);
    expect(split.json['letterlessKinds'], {'noBox': 1});
  });

  test('lines that start with a lone mark are counted, and no word with a '
      'letter fails beside one', () async {
    final nonsense = SyntheticArabicScript(17);
    final lengths = Random(17);
    final run = await _measure(root, [
      (
        name: nonsense.word(),
        bismillah: null,
        ayat: [
          for (var a = 0; a < 200; a++)
            [
              nonsense.phrase(4 + lengths.nextInt(12)),
              String.fromCharCode(0x06D6 + a % 7),
            ].join(' '),
        ],
      ),
    ]);
    final m = run.measurement;
    final layout =
        ((m.results['surahs']! as List<Map<String, Object?>>).single['runs']!
                as List<Map<String, Object?>>)
            .single;
    final breaks = layout['lineBreaks']! as Map<String, Object?>;
    final hit = layout['hit']! as Map<String, Object?>;
    expect(breaks['startsWithLetterless'], greaterThan(0));
    expect(breaks['endsBeforeLetterless'], breaks['startsWithLetterless']);
    expect(hit['letterlessWords'], 200);
    expect(hit['unexplainedProblems'], 0);
    expect(m.problemCounts[ProblemKind.hitRoundTrip], 0);
    final summary = summaryLines(m.results);
    expect(summary, contains(startsWith('  lines starting with a word')));
    expect(summary.join('\n').runes.where((c) => c > 0x7E), isEmpty);
  });

  test('the long surah of the render tests, V2 included, at one width and '
      'scale', () async {
    final pack = await openSyntheticSpikePack(root);
    final surah = (await readWholePack(pack)).surahs.first;
    pack.close();
    final run = await measureSurahLayout(surah, width: 412, scale: 2);
    for (final kind in ProblemKind.values) {
      expect(
        run.problems[kind] ?? const <String>[],
        isEmpty,
        reason: kind.name,
      );
    }
    final v2 = run.json['v2']! as Map<String, Object?>;
    expect(v2['sameLineStartsAsV1'], isTrue);
    expect(v2['fingerprint'], run.json['fingerprint']);
    expect(v2['blocks'], greaterThan(10));
    expect(run.json['slicedAyat'], syntheticLongAyat);
    expect(jsonEncode(run.json).runes.where((c) => c > 0x7E), isEmpty);
  });
}
