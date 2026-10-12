import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/data/services/pack_database.dart';
import 'package:holyquran/data/services/surah_name_index.dart';

import '../../../testing/packs/synthetic_pack.dart';

// Every name is synthetic; non-ASCII characters are written as escapes.

/// A synthetic Arabic-script name: two words that read "test text".
const _arabicName = '\u0646\u0635 \u062A\u062C\u0631\u064A\u0628\u064A';

/// A decomposed e-acute: the same letters precomposed are another name.
const _decomposed = 'Synthe\u0301tic decomposed';
const _precomposed = 'Synth\u00E9tic decomposed';

SyntheticSurah _surah(String name) =>
    SyntheticSurah(name: name, ayat: const [SyntheticAyah('Synthetic ayah')]);

void main() {
  late Directory root;
  late SurahNameIndex index;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('surah_name_index_test');
    final pack = await buildSyntheticPack(
      root,
      surahs: [
        _surah('Synthetic one'),
        _surah(_arabicName),
        _surah(_decomposed),
      ],
      divisions: const [
        SyntheticDivision('juz', 1, 1, 1),
        SyntheticDivision('hizb', 1, 1, 1),
        SyntheticDivision('rub', 1, 1, 1),
        SyntheticDivision('page', 1, 1, 1),
      ],
      sajdas: const [],
    );
    final database = PackDatabase.open(pack.textFile.path, formatVersion: 1);
    index = SurahNameIndex(database.surahs());
    database.close();
  });
  tearDownAll(() => root.delete(recursive: true));

  test('finds each surah by the name the pack stores', () {
    expect(index.surahNamed('Synthetic one'), 1);
    expect(index.surahNamed(_arabicName), 2);
    expect(index.surahNamed(_decomposed), 3);
  });

  test('matches a name only whole and exactly as stored', () {
    for (final query in [
      '',
      'Synthetic',
      'Synthetic one ',
      ' Synthetic one',
      'Synthetic  one',
      'synthetic one',
      'SYNTHETIC ONE',
      'Synthetic one two',
      _precomposed,
      '\u0646\u0635',
      // The two words joined by a no-break space instead of a space.
      '\u0646\u0635\u00A0\u062A\u062C\u0631\u064A\u0628\u064A',
    ]) {
      expect(index.surahNamed(query), isNull, reason: query);
    }
  });
}
