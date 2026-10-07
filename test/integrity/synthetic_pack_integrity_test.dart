import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../testing/packs/synthetic_pack.dart';
import 'pack_integrity_suite.dart';

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

    test('words whose gap is not a space', () {
      final ayat = defaultSyntheticSurahs.expand((s) => s.ayat);
      expect(ayat.where((ayah) => ayah.words != null), isNotEmpty);
    });
  });

  group('wordSpanProblems', () {
    test('accepts spans whose gaps are the text own spaces', () {
      expect(
        wordSpanProblems('x', ' ab  cd ', [(1, 1, 3), (2, 5, 7)]),
        isEmpty,
      );
      expect(wordSpanProblems('x', 'ab-cd', [(1, 0, 2), (2, 3, 5)]), isEmpty);
      expect(wordSpanProblems('x', '', []), isEmpty);
    });

    test('flags overlapping, empty and out-of-bounds spans', () {
      expect(wordSpanProblems('x', 'abcdef', [(1, 0, 3), (2, 2, 5)]), [
        startsWith('x:2: span [2, 5)'),
      ]);
      expect(wordSpanProblems('x', 'abcdef', [(1, 2, 2)]), [
        startsWith('x:1: span [2, 2)'),
      ]);
      expect(wordSpanProblems('x', 'abc', [(1, 0, 4)]), [
        startsWith('x:1: span [0, 4)'),
      ]);
    });

    test('flags numbers that are not 1 to n', () {
      expect(wordSpanProblems('x', 'ab cd', [(1, 0, 2), (3, 3, 5)]), [
        'x: word 2 is numbered 3',
      ]);
    });

    test('flags an offset inside a surrogate pair', () {
      expect(
        wordSpanProblems('x', 'a\u{1F600}b', [(1, 0, 2), (2, 2, 4)]),
        containsAll([
          'x:1: offset 2 splits a surrogate pair',
          'x:2: offset 2 splits a surrogate pair',
          'x: the slices and gaps do not rejoin to the ayah',
        ]),
      );
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
      expect(await wordSpanProblemsOfPack(await built(surahs: surahs)), [
        startsWith('hafs:2:3:2: span [5, 14)'),
      ]);
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
    });
  });
}
