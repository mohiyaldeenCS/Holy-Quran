import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/pack_failure.dart';
import 'package:holyquran/domain/models/verified_pack.dart';
import 'package:holyquran/utils/result.dart';

import '../../testing/packs/synthetic_pack.dart';
import 'pack_integrity_suite.dart';
import 'synthetic_surahs.dart';

// Every string is synthetic; non-ASCII characters are written as escapes.

void main() {
  late Directory root;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('synthetic_pack_integrity');
  });
  tearDownAll(() => root.delete(recursive: true));

  definePackIntegritySuite(
    'a synthetic pack',
    () async => (await buildSyntheticPack(root)).directory.path,
  );

  group('the synthetic pack holds text that any change would break:', () {
    final texts = [
      for (final surah in defaultSyntheticSurahs) ...[
        surah.name,
        ?surah.basmala,
        for (final ayah in surah.ayat) ayah.text,
      ],
    ];
    final ayat = defaultSyntheticSurahs.expand((s) => s.ayat);

    test('NFC-unstable text, decomposed and precomposed', () {
      expect(texts, anyElement(contains('e\u{301}')));
      expect(texts, anyElement(contains('\u{E9}')));
    });

    test('leading, trailing and double spaces', () {
      expect(texts, anyElement(startsWith(' ')));
      expect(texts, anyElement(endsWith(' ')));
      expect(texts, anyElement(contains('  ')));
    });

    test('a character outside the BMP', () {
      expect(texts.any((text) => text.runes.any((r) => r > 0xFFFF)), isTrue);
    });

    test('surahs with and without a basmala', () {
      final basmalas = defaultSyntheticSurahs.map((s) => s.basmala != null);
      expect(basmalas, containsAll([true, false]));
    });

    test('marks before the first word, between words and after the last', () {
      final places = {
        for (final ayah in ayat)
          for (final mark in ayah.markSpans)
            switch (mark.afterWord) {
              0 => 'before',
              final w when w == ayah.spans.length => 'after',
              _ => 'between',
            },
      };
      expect(places, {'before', 'between', 'after'});
    });

    test('a mark outside the BMP, and a word holding a non-letter', () {
      expect(
        ayat.any(
          (ayah) => ayah.markSpans.any(
            (m) => ayah.text.substring(m.start, m.end).runes.single > 0xFFFF,
          ),
        ),
        isTrue,
      );
      expect(
        ayat.any(
          (ayah) => ayah.spans.any(
            (w) => ayah.text.substring(w.$1, w.$2).contains('-'),
          ),
        ),
        isTrue,
      );
    });
  });

  group('spanProblems', () {
    test('accepts words and marks whose gaps are the text own spaces', () {
      expect(
        spanProblems('x', ' ab  ! cd ', [(1, 1, 3), (2, 7, 9)], [(1, 1, 5, 6)]),
        isEmpty,
      );
      expect(
        spanProblems('x', '! ab ?', [(1, 2, 4)], [(1, 0, 0, 1), (2, 1, 5, 6)]),
        isEmpty,
      );
      expect(spanProblems('x', 'ab-cd', [(1, 0, 2), (2, 3, 5)], []), isEmpty);
      expect(spanProblems('x', '', [], []), isEmpty);
    });

    test('flags overlapping, empty, out-of-bounds and reordered words', () {
      expect(spanProblems('x', 'abcdef', [(1, 0, 3), (2, 2, 5)], []), [
        startsWith('x: word 2 span [2, 5) is not after the span before'),
      ]);
      expect(spanProblems('x', 'abcdef', [(1, 2, 2)], []), [
        startsWith('x: word 1 span [2, 2)'),
      ]);
      expect(spanProblems('x', 'abc', [(1, 0, 4)], []), [
        startsWith('x: word 1 span [0, 4)'),
      ]);
      expect(spanProblems('x', 'ab cd', [(1, 3, 5), (2, 0, 2)], []), [
        startsWith('x: word 2 span [0, 2)'),
      ]);
    });

    test('flags a mark that overlaps a word, is empty or out of bounds', () {
      expect(
        spanProblems('x', 'ab! cd', [(1, 0, 2), (2, 4, 6)], [(1, 1, 1, 3)]),
        [startsWith('x: mark 1 span [1, 3) is not after the span before')],
      );
      expect(
        spanProblems('x', 'ab! cd', [(1, 0, 2), (2, 4, 6)], [(1, 1, 2, 5)]),
        [startsWith('x: word 2 span [4, 6) is not after the span before')],
      );
      expect(spanProblems('x', 'ab !', [(1, 0, 2)], [(1, 1, 3, 3)]), [
        startsWith('x: mark 1 span [3, 3)'),
      ]);
      expect(spanProblems('x', 'ab !', [(1, 0, 2)], [(1, 1, 3, 5)]), [
        startsWith('x: mark 1 span [3, 5)'),
      ]);
    });

    test('flags numbers that are not 1 to n', () {
      expect(spanProblems('x', 'ab cd', [(1, 0, 2), (3, 3, 5)], []), [
        'x: word 2 is numbered 3',
      ]);
      expect(spanProblems('x', 'ab ! ?', [(1, 0, 2)], [(2, 1, 3, 4)]), [
        'x: mark 1 is numbered 2',
      ]);
    });

    test('flags an after_word other than the words before the mark', () {
      expect(
        spanProblems('x', 'ab ! cd', [(1, 0, 2), (2, 5, 7)], [(1, 2, 3, 4)]),
        ['x: mark 1 has after_word 2, not 1'],
      );
      expect(spanProblems('x', '! ab', [(1, 2, 4)], [(1, 1, 0, 1)]), [
        'x: mark 1 has after_word 1, not 0',
      ]);
    });

    test('flags an offset inside a surrogate pair', () {
      expect(
        spanProblems('x', 'a\u{1F600}b', [(1, 0, 2), (2, 2, 4)], []),
        containsAll([
          'x: word 1 offset 2 splits a surrogate pair',
          'x: word 2 offset 2 splits a surrogate pair',
          'x: the slices and gaps do not rejoin to the ayah',
        ]),
      );
      expect(
        spanProblems(
          'x',
          'a\u{1F600}b',
          [(1, 0, 1), (2, 3, 4)],
          [(1, 1, 1, 2)],
        ),
        containsAll([
          'x: mark 1 offset 2 splits a surrogate pair',
          'x: the slices and gaps do not rejoin to the ayah',
        ]),
      );
    });
  });

  group('gapProblems', () {
    test('accepts gaps of U+0020 only, at the ends too', () {
      expect(
        gapProblems('x', ' ab  ! cd ', [(1, 1, 3), (2, 7, 9)], [(1, 1, 5, 6)]),
        isEmpty,
      );
      expect(gapProblems('x', '   ', [], []), isEmpty);
      expect(gapProblems('x', '', [], []), isEmpty);
    });

    test('flags a gap holding anything else, once per gap', () {
      expect(gapProblems('x', 'ab-cd', [(1, 0, 2), (2, 3, 5)], []), [
        'x: the gap [2, 3) holds U+002D at offset 2',
      ]);
      expect(gapProblems('x', 'ab c', [(1, 0, 2)], []), [
        'x: the gap [2, 4) holds U+0063 at offset 3',
      ]);
      expect(gapProblems('x', 'abc', [], []), [
        'x: the gap [0, 3) holds U+0061 at offset 0',
      ]);
      expect(gapProblems('x', 'ab\u{A0}cd\tef', [(1, 0, 2), (2, 3, 5)], []), [
        'x: the gap [2, 3) holds U+00A0 at offset 2',
        'x: the gap [5, 8) holds U+0009 at offset 5',
      ]);
      expect(gapProblems('x', '\u{1F600} ab', [(1, 3, 5)], []), [
        'x: the gap [0, 3) holds U+1F600 at offset 0',
      ]);
      expect(gapProblems('x', '\u{FEFF}ab', [(1, 1, 3)], []), [
        'x: the gap [0, 1) holds U+FEFF at offset 0',
      ]);
    });

    test('counts what marks cover as covered', () {
      expect(
        gapProblems('x', 'ab-cd', [(1, 0, 2), (2, 3, 5)], [(1, 1, 2, 3)]),
        isEmpty,
      );
    });
  });

  group('tokenProblems', () {
    test('accepts spans that are whole tokens, at the edges too', () {
      expect(
        tokenProblems(
          'x',
          ' ab  ! cd ',
          [(1, 1, 3), (2, 7, 9)],
          [(1, 1, 5, 6)],
        ),
        isEmpty,
      );
      expect(
        tokenProblems('x', '! ab ?', [(1, 2, 4)], [(1, 0, 0, 1), (2, 1, 5, 6)]),
        isEmpty,
      );
      expect(tokenProblems('x', 'ab', [(1, 0, 9)], [(1, 1, 3, 1)]), isEmpty);
    });

    test('flags a mark that swallows the separator', () {
      expect(tokenProblems('x', 'ab !', [(1, 0, 2)], [(1, 1, 2, 4)]), [
        'x: mark 1 [2, 4) holds the separator at offset 2',
        'x: mark 1 [2, 4) does not start a token',
      ]);
    });

    test('flags two tokens in one word', () {
      expect(tokenProblems('x', 'ab cd', [(1, 0, 5)], []), [
        'x: word 1 [0, 5) holds the separator at offset 2',
      ]);
    });

    test('flags a token split between a word and a mark', () {
      expect(tokenProblems('x', 'ab!', [(1, 0, 2)], [(1, 1, 2, 3)]), [
        'x: word 1 [0, 2) does not end a token',
        'x: mark 1 [2, 3) does not start a token',
      ]);
    });
  });

  group('letterProblems', () {
    test('accepts Latin, Latin-1 and Arabic words, and letterless marks', () {
      expect(
        letterProblems('x', 'ab \u{6D6}', [(1, 0, 2)], [(1, 1, 3, 4)]),
        isEmpty,
      );
      expect(
        letterProblems('x', 'e\u{301} \u{E9}', [(1, 0, 2), (2, 3, 4)], []),
        isEmpty,
      );
      expect(
        letterProblems(
          'x',
          '\u{628}\u{64E} \u{6DE}',
          [(1, 0, 2)],
          [(1, 1, 3, 4)],
        ),
        isEmpty,
      );
      expect(
        letterProblems('x', 'a \u{1F600}', [(1, 0, 1)], [(1, 1, 2, 4)]),
        isEmpty,
      );
      expect(letterProblems('x', 'ab', [(1, 0, 9)], [(1, 1, 3, 1)]), isEmpty);
    });

    test('flags a word with no letter', () {
      expect(letterProblems('x', 'ab \u{6D6}', [(1, 0, 2), (2, 3, 4)], []), [
        'x: word 2 [3, 4) holds no letter',
      ]);
      expect(letterProblems('x', '12 -\u{301}', [(1, 0, 2), (2, 3, 5)], []), [
        'x: word 1 [0, 2) holds no letter',
        'x: word 2 [3, 5) holds no letter',
      ]);
    });

    test('flags a mark with a letter, by its first letter', () {
      expect(letterProblems('x', 'ab cd', [(1, 0, 2)], [(1, 1, 3, 5)]), [
        'x: mark 1 [3, 5) holds the letter U+0063 at offset 3',
      ]);
      expect(letterProblems('x', '\u{6D6}\u{628}', [], [(1, 0, 0, 2)]), [
        'x: mark 1 [0, 2) holds the letter U+0628 at offset 1',
      ]);
      expect(letterProblems('x', '\u{1EE00}', [], [(1, 0, 0, 2)]), [
        'x: mark 1 [0, 2) holds the letter U+1EE00 at offset 0',
      ]);
    });
  });

  group('optionsProblems', () {
    Map<String, Object?> source(Object? options) => {'options': options};

    test('accepts options read as manifest.json gives them, or null', () {
      expect(
        optionsProblems(
          [
            {'a': 'x', 'b': 1, 'c': true},
            null,
          ],
          [
            source({'a': 'x', 'b': 1, 'c': true}),
            source(null),
          ],
        ),
        isEmpty,
      );
    });

    test('flags options missing, read otherwise, or not scalar', () {
      expect(
        optionsProblems(
          [null],
          [
            {'role': 'text'},
          ],
        ),
        ['sources[0].options is missing from manifest.json'],
      );
      expect(
        optionsProblems(
          [
            {'a': 'x'},
          ],
          [
            source({'a': 'y'}),
          ],
        ),
        ['sources[0].options[a] is not read as manifest.json gives it'],
      );
      expect(
        optionsProblems(
          [
            {'a': 'x'},
          ],
          [
            source({
              'a': {'b': 1},
            }),
          ],
        ),
        ['sources[0].options[a] is not a string, number or boolean'],
      );
      expect(
        optionsProblems(
          [null],
          [
            source({'a': 'x'}),
          ],
        ),
        ['sources[0].options is not read as manifest.json gives it'],
      );
      expect(optionsProblems([null], []), [
        'manifest.json does not list 1 sources',
      ]);
    });
  });

  group('the checks catch', () {
    Future<PackUnderTest> load(SyntheticPack pack) async {
      final loaded = await PackUnderTest.load(pack.directory.path);
      addTearDown(loaded.close);
      return loaded;
    }

    var builds = 0;
    Future<PackUnderTest> built({
      SyntheticFault? fault,
      List<SyntheticSurah> surahs = defaultSyntheticSurahs,
      List<SyntheticDivision> divisions = defaultSyntheticDivisions,
    }) async => load(
      await buildSyntheticPack(
        root,
        fault: fault,
        surahs: surahs,
        divisions: divisions,
        id: 'faulty-${builds++}',
      ),
    );

    test('a file left in WAL mode', () async {
      expect(
        await headerProblems(await built(fault: SyntheticFault.walHeader)),
        ['header byte 18 is 2, not 1', 'header byte 19 is 2, not 1'],
      );
    });

    test('a wrong application_id or user_version', () async {
      expect(
        await headerProblems(
          await built(fault: SyntheticFault.wrongApplicationId),
        ),
        [startsWith('application_id is ')],
      );
      expect(
        await headerProblems(
          await built(fault: SyntheticFault.wrongUserVersion),
        ),
        [startsWith('user_version is ')],
      );
    });

    test('counts that differ from the rows', () async {
      final problems = await countProblems(
        await built(fault: SyntheticFault.wrongCounts),
      );
      expect(problems, anyElement(startsWith('counts.ayat is ')));
      expect(problems, anyElement(startsWith('surah list: PackInconsistent')));
    });

    test('a surah digest that differs from the manifest', () async {
      expect(
        await digestProblems(await built(fault: SyntheticFault.wrongSurahHash)),
        [
          'surah 1: the production digest differs from the manifest',
          'surah 1: the independent digest differs from the manifest',
        ],
      );
    });

    test('a text stored with a leading EF BB BF', () async {
      final pack = await built(fault: SyntheticFault.leadingBom);
      expect(await bomProblems(pack), ['ayah 1:1']);
      expect(
        await storedTextProblems(pack),
        anyElement(contains('TextEncodingRejected')),
      );
    });

    test('overlapping word spans', () async {
      final surahs = [...defaultSyntheticSurahs];
      final second = surahs[1];
      surahs[1] = SyntheticSurah(
        name: second.name,
        revelationPlace: second.revelationPlace,
        revelationOrder: second.revelationOrder,
        ayat: [
          ...second.ayat.take(2),
          SyntheticAyah(
            second.ayat[2].text,
            words: const [(0, 9), (5, 14), (15, 21)],
          ),
        ],
      );
      final problems = await spanProblemsOfPack(await built(surahs: surahs));
      expect(problems.where((p) => p.contains('span [')), [
        startsWith('hafs:2:3: word 2 span [5, 14)'),
      ]);
      expect(
        problems,
        contains(
          'hafs:2:1: PackInconsistent(faulty-${builds - 1}): hafs:2:3: '
          'word 2 overlaps the word before: [5, 14)',
        ),
      );
      expect(
        problems.where((p) => p.startsWith('hafs:1:')),
        isEmpty,
        reason: 'surah 1 is read before surah 2 disables the pack',
      );
    });

    test('a counts.marks other than the mark rows', () async {
      final problems = await countProblems(
        await built(fault: SyntheticFault.wrongMarkCount),
      );
      expect(
        problems,
        containsAll([
          'counts.marks is 6; the file holds 5',
          startsWith('surah list: PackInconsistent'),
        ]),
      );
    });

    test('a mark that overlaps the word before it', () async {
      final pack = await built(fault: SyntheticFault.markOverlapsWord);
      final spans = await spanProblemsOfPack(pack);
      const overlap =
          'hafs:1:2: mark 1 span [10, 13) is not after the span before, not '
          'empty and within 21 code units';
      expect(spans.where((p) => p.contains('span [')), [overlap]);
      expect(
        spans.first,
        'hafs:1:1: PackInconsistent(faulty-${builds - 1}): hafs:1:2: mark 1 '
        'overlaps the word before: [10, 13)',
      );
      expect(await letterProblemsOfPack(pack), [
        'hafs:1:2: mark 1 [10, 13) holds the letter U+00E9 at offset 10',
      ]);
      expect(await gapProblemsOfPack(pack), isEmpty);
    });

    test('a mark whose after_word is not the words before it', () async {
      final problems = await spanProblemsOfPack(
        await built(fault: SyntheticFault.wrongAfterWord),
      );
      expect(
        problems.where((p) => p.contains('after_word')),
        everyElement(contains('mark 1 has after_word 3, not 2')),
      );
      expect(problems, contains('hafs:1:2: mark 1 has after_word 3, not 2'));
      expect(
        problems,
        contains(
          'hafs:1:1: PackInconsistent(faulty-${builds - 1}): hafs:1:2: '
          'mark 1 has after_word 3, not 2: [12, 13)',
        ),
      );
    });

    test('text outside every span other than U+0020, words without a '
        'letter and marks with one', () async {
      final pack = await built(
        surahs: withAyat(defaultSyntheticSurahs, 3, const [
          SyntheticAyah('ab-cd ef', words: [(0, 2), (3, 5), (6, 8)]),
          SyntheticAyah('ab c', words: [(0, 2)]),
          SyntheticAyah('ab \u{6D6}', words: [(0, 2), (3, 4)]),
          SyntheticAyah(
            'ab cd',
            words: [(0, 2)],
            marks: [(afterWord: 1, start: 3, end: 5)],
          ),
        ]),
      );
      expect(pack.verification, isA<Ok<VerifiedPack>>());
      expect(await spanProblemsOfPack(pack), isEmpty);
      expect(await gapProblemsOfPack(pack), [
        'hafs:3:1: the gap [2, 3) holds U+002D at offset 2',
        'hafs:3:2: the gap [2, 4) holds U+0063 at offset 3',
      ]);
      expect(await tokenProblemsOfPack(pack), [
        'hafs:3:1: word 1 [0, 2) does not end a token',
        'hafs:3:1: word 2 [3, 5) does not start a token',
      ]);
      expect(await letterProblemsOfPack(pack), [
        'hafs:3:3: word 2 [3, 4) holds no letter',
        'hafs:3:4: mark 1 [3, 5) holds the letter U+0063 at offset 3',
      ]);
    });

    test('spans that are not whole tokens', () async {
      final pack = await built(
        surahs: withAyat(defaultSyntheticSurahs, 3, const [
          SyntheticAyah(
            'ab !',
            words: [(0, 2)],
            marks: [(afterWord: 1, start: 2, end: 4)],
          ),
          SyntheticAyah('ab cd', words: [(0, 5)]),
          SyntheticAyah(
            'ab!',
            words: [(0, 2)],
            marks: [(afterWord: 1, start: 2, end: 3)],
          ),
        ]),
      );
      expect(pack.verification, isA<Ok<VerifiedPack>>());
      expect(await spanProblemsOfPack(pack), isEmpty);
      expect(await gapProblemsOfPack(pack), isEmpty);
      expect(await tokenProblemsOfPack(pack), [
        'hafs:3:1: mark 1 [2, 4) holds the separator at offset 2',
        'hafs:3:1: mark 1 [2, 4) does not start a token',
        'hafs:3:2: word 1 [0, 5) holds the separator at offset 2',
        'hafs:3:3: word 1 [0, 2) does not end a token',
        'hafs:3:3: mark 1 [2, 3) does not start a token',
      ]);
    });

    test('a stored leading U+FEFF outside every span', () async {
      expect(
        await gapProblemsOfPack(await built(fault: SyntheticFault.leadingBom)),
        ['hafs:1:1: the gap [0, 1) holds U+FEFF at offset 0'],
      );
    });

    test('divisions with a gap in their numbers or out of order', () async {
      List<SyntheticDivision> replacingLastPage(SyntheticDivision page) => [
        for (final d in defaultSyntheticDivisions)
          if (d.kind == 'page' && d.number == 4) page else d,
      ];
      expect(
        await referenceProblems(
          await built(
            divisions: replacingLastPage(
              const SyntheticDivision('page', 5, 3, 1),
            ),
          ),
        ),
        containsAll([
          'page units are numbered (1, 2, 3, 5)',
          startsWith('edition map: PackInconsistent'),
        ]),
      );
      expect(
        await referenceProblems(
          await built(
            divisions: replacingLastPage(
              const SyntheticDivision('page', 4, 1, 1),
            ),
          ),
        ),
        containsAll([
          'page 4 does not start after page 3',
          startsWith('edition map: PackInconsistent'),
        ]),
      );
    });

    test('a manifest font other than the pinned file', () async {
      final pack = await buildSyntheticPack(root, id: 'other-font');
      final manifest =
          jsonDecode(await pack.manifestFile.readAsString())
              as Map<String, Object?>;
      manifest['font'] = {
        'family': 'Synthetic Font',
        'version': '9.999',
        'sha256': sha256.convert(utf8.encode('synthetic font')).toString(),
      };
      await pack.manifestFile.writeAsString(jsonEncode(manifest));
      expect(await fontProblems(await load(pack)), [
        startsWith('font.sha256 is not'),
        startsWith('font.family is Synthetic Font; QuranText'),
        startsWith('font.family is Synthetic Font; assets'),
        startsWith('font.version is 9.999;'),
      ]);
    });

    test('a pack in a directory its version does not name', () async {
      final pack = await buildSyntheticPack(root, id: 'moved');
      final moved = await pack.directory.rename('${root.path}/moved/7');
      final loaded = await PackUnderTest.load(moved.path);
      addTearDown(loaded.close);
      expect(await locationProblems(loaded), [
        'the pack sits in moved/7, not moved/1',
      ]);
      expect(
        loaded.verification,
        isA<Failure<VerifiedPack>>().having(
          (f) => f.error,
          'error',
          isA<ManifestUnreadable>(),
        ),
      );
    });
  });
}
