import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/data/models/pack_manifest_json.dart';
import 'package:holyquran/data/repositories/tafsir_search_repository.dart';
import 'package:holyquran/domain/models/pack_failure.dart';
import 'package:holyquran/domain/models/pack_manifest.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/search_hit.dart';
import 'package:holyquran/domain/models/search_match.dart';
import 'package:holyquran/domain/models/verified_pack.dart';
import 'package:holyquran/utils/result.dart';

import '../../../testing/packs/synthetic_files.dart';
import '../../../testing/packs/synthetic_tafsir_pack.dart';

// Every passage is synthetic, never tafsir text; non-ASCII characters are
// written as escapes. The Arabic-script letters below spell nothing.

const _letters = '\u0633\u064A\u0646';
const _marked = '\u0633\u064E\u064A\u0652\u0646';

const _secondBook = [
  SyntheticPassage(1, 1, 1, 'Synthetic $_marked one'),
  SyntheticPassage(2, 1, 2, '$_letters and $_letters\u064F twice'),
  SyntheticPassage(3, 1, 1, 'Synthetic e\u0301 \u{1F600}'),
];

void main() {
  late Directory root;
  late List<VerifiedPack> installed;
  late List<Exception> failures;
  late TafsirSearchRepository repository;
  final texts = <(String, int), String>{};

  Future<VerifiedPack> install(
    String id,
    List<SyntheticPassage> passages, {
    SyntheticTafsirFault? fault,
  }) async {
    final pack = await buildSyntheticTafsirPack(
      root,
      id: id,
      passages: passages,
      fault: fault,
    );
    for (final (i, passage) in pack.passages.indexed) {
      texts[(id, i + 1)] = passage.text;
    }
    final manifest = File('${pack.directory.path}/$manifestFileName');
    return VerifiedPack(
      directory: pack.directory.path,
      manifest:
          (parsePackManifest(manifest.readAsBytesSync(), pack: id)
                  as Ok<PackManifest>)
              .value,
      signatureChecked: false,
    );
  }

  setUp(() async {
    root = Directory.systemTemp.createTempSync('tafsir_search');
    failures = [];
    installed = [
      await install('synthetic-a', defaultSyntheticPassages),
      await install('synthetic-b', _secondBook),
    ];
    repository = PackTafsirSearchRepository(
      installed: () async => installed,
      surahCount: 3,
      onFailed: failures.add,
    );
  });
  tearDown(() => root.deleteSync(recursive: true));

  Future<List<TafsirHit>> search(String query, List<String> books) async =>
      (await repository.search(query, books) as Ok<List<TafsirHit>>).value;

  List<(String, int)> passagesOf(List<TafsirHit> hits) => [
    for (final hit in hits) (hit.book, hit.passage.number),
  ];

  /// What each match covers, sliced from the stored passage.
  List<String> slices(List<TafsirHit> hits) => [
    for (final hit in hits)
      for (final SearchMatch(:start, :end) in hit.matches)
        texts[(hit.book, hit.passage.number)]!.substring(start, end),
  ];

  test('searches several books, book by book in the order given', () async {
    final both = await search('Synthetic', ['synthetic-a', 'synthetic-b']);
    expect(passagesOf(both), [
      ('synthetic-a', 3),
      ('synthetic-a', 4),
      ('synthetic-b', 1),
      ('synthetic-b', 3),
    ]);
    expect(slices(both), everyElement('Synthetic'));
    final reversed = await search('Synthetic', ['synthetic-b', 'synthetic-a']);
    expect(passagesOf(reversed).first, ('synthetic-b', 1));
  });

  test('searches one book', () async {
    expect(passagesOf(await search('Synthetic', ['synthetic-b'])), [
      ('synthetic-b', 1),
      ('synthetic-b', 3),
    ]);
  });

  test('gives each passage whole, with its range', () async {
    final hit = (await search('inside', ['synthetic-a'])).single;
    expect(hit.passage.range.toString(), 'hafs:2:2-2:3');
    expect(hit.passage.text, PackText.fromPack(texts[('synthetic-a', 3)]!));
  });

  test('matches over the harakat of the passage, as the query fold', () async {
    for (final query in [_letters, _marked, ' $_letters\u0650 ']) {
      final hits = await search(query, ['synthetic-b']);
      expect(passagesOf(hits), [('synthetic-b', 1), ('synthetic-b', 2)]);
      expect(hits[0].matches, [const SearchMatch(start: 10, end: 15)]);
      expect(hits[1].matches.length, 2);
      expect(slices(hits), [_marked, _letters, '$_letters\u064F']);
    }
  });

  test('matches words in order, offsets slicing the stored text', () async {
    final hits = await search(syntheticArabic, ['synthetic-a']);
    expect(passagesOf(hits), [('synthetic-a', 1), ('synthetic-a', 2)]);
    expect(slices(hits), [syntheticArabic, syntheticArabic]);
    expect(await search('over Synthetic', ['synthetic-a']), isEmpty);
  });

  test('compares every other unit exactly', () async {
    expect(slices(await search('\u00E9', ['synthetic-a'])), ['\u00E9']);
    expect(await search('synthetic', ['synthetic-a']), isEmpty);
  });

  test('never cuts a surrogate pair', () async {
    expect(await search('\uD83D', ['synthetic-a', 'synthetic-b']), isEmpty);
    expect(slices(await search('\u{1F600}', ['synthetic-b'])), ['\u{1F600}']);
  });

  test('a query with no words finds nothing', () async {
    expect(await search(' \u064E ', ['synthetic-a']), isEmpty);
  });

  test('leaves out a book no longer installed', () async {
    expect(passagesOf(await search('Synthetic', ['absent', 'synthetic-b'])), [
      ('synthetic-b', 1),
      ('synthetic-b', 3),
    ]);
  });

  test('a space of the query meets any run of white space', () async {
    expect(slices(await search('Synthetic  last', ['synthetic-a'])), [
      'Synthetic\nlast',
    ]);
  });

  test('a book that breaks the format fails, naming it', () async {
    installed.add(
      await install(
        'synthetic-broken',
        defaultSyntheticPassages,
        fault: SyntheticTafsirFault.overlappingPassages,
      ),
    );
    final result = await repository.search('Synthetic', [
      'synthetic-a',
      'synthetic-broken',
    ]);
    expect(
      result,
      isA<Failure<List<TafsirHit>>>().having(
        (f) => f.error,
        'error',
        isA<PackInconsistent>().having(
          (f) => f.pack,
          'pack',
          'synthetic-broken',
        ),
      ),
    );
    expect(failures, [(result as Failure).error]);
  });
}
