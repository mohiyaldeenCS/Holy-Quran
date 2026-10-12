import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/data/repositories/local_pack_repository.dart';
import 'package:holyquran/data/repositories/pack_quran_text_repository.dart';
import 'package:holyquran/data/repositories/quran_index_repository.dart';
import 'package:holyquran/data/services/manifest_signature.dart';
import 'package:holyquran/data/services/pack_file_service.dart';
import 'package:holyquran/domain/models/division_entry.dart';
import 'package:holyquran/domain/models/edition_map.dart';
import 'package:holyquran/domain/models/pack_failure.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/quran_position.dart';
import 'package:holyquran/domain/models/surah_info.dart';
import 'package:holyquran/utils/result.dart';

import '../../../testing/packs/synthetic_pack.dart';

QuranAddress _at(String address) => QuranAddress.parse(address);

bool _serving() => true;

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('quran_index_repository_test');
  });
  tearDown(() => root.delete(recursive: true));

  Future<PackQuranTextRepository> textOf(SyntheticPack pack) async {
    const verifier = LocalPackRepository(
      files: PackFileService(),
      signatures: SignatureNotConfigured(),
    );
    final verified = switch (await verifier.verify(pack.directory.path)) {
      Ok(:final value) => value,
      Failure(:final error) => throw error,
    };
    final text = switch (PackQuranTextRepository.open(verified)) {
      Ok(:final value) => value,
      Failure(:final error) => throw error,
    };
    addTearDown(text.close);
    return text;
  }

  Future<Result<PackQuranIndexRepository>> load({
    List<SyntheticDivision> divisions = defaultSyntheticDivisions,
    bool Function() serving = _serving,
  }) async {
    final text = await textOf(
      await buildSyntheticPack(root, divisions: divisions),
    );
    return PackQuranIndexRepository.build(
      riwaya: text.riwaya,
      surahs: (await text.surahs() as Ok<List<SurahInfo>>).value,
      map: (await text.editionMap() as Ok<EditionMap>).value,
      serving: serving,
    );
  }

  Future<PackQuranIndexRepository> loaded() async => switch (await load()) {
    Ok(:final value) => value,
    Failure(:final error) => throw error,
  };

  test('lists the surahs with their facts and first page', () async {
    final surahs = (await loaded()).surahs;

    expect([for (final s in surahs) s.number], [1, 2, 3]);
    expect([for (final s in surahs) s.ayahCount], [4, 3, 1]);
    expect(
      [for (final s in surahs) s.revelationPlace],
      [RevelationPlace.makki, RevelationPlace.madani, null],
    );
    expect([for (final s in surahs) s.revelationOrder], [2, 1, null]);
    expect(surahs.first.name, isNot(surahs.last.name));
  });

  test('gives the first page of each surah', () async {
    final index = await loaded();

    expect([for (var s = 1; s <= 3; s++) index.firstPage(s)], [1, 2, 4]);
    expect(() => index.firstPage(0), throwsRangeError);
  });

  test('answers the structure of the edition', () async {
    final index = await loaded();

    expect(index.riwaya, 'hafs');
    expect(index.surahCount, 3);
    expect(index.ayahCount(2), 3);
    expect(index.nextSurah(2), 3);
    expect(index.nextSurah(3), isNull);
    expect(index.count(Division.page), 4);
    expect(index.count(Division.rub), 8);
    expect(index.firstAyah(Division.hizb, 2), _at('hafs:1:3'));
    expect(index.numberAt(Division.page, _at('hafs:2:1:2')), 2);
  });

  test('refuses numbers and addresses outside the edition', () async {
    final index = await loaded();

    expect(() => index.ayahCount(0), throwsRangeError);
    expect(() => index.ayahCount(4), throwsRangeError);
    expect(() => index.nextSurah(4), throwsRangeError);
    expect(() => index.pageStartsIn(4), throwsRangeError);
    expect(() => index.firstAyah(Division.juz, 3), throwsRangeError);
    for (final address in ['hafs:4:1', 'hafs:1:5', 'warsh:1:1']) {
      expect(() => index.positionOf(_at(address)), throwsArgumentError);
      expect(
        () => index.numberAt(Division.juz, _at(address)),
        throwsArgumentError,
      );
    }
  });

  test('lists every division with its first ayah and page', () async {
    final index = await loaded();

    expect(index.divisions(Division.juz), [
      DivisionEntry(
        division: Division.juz,
        number: 1,
        firstAyah: _at('hafs:1:1'),
        firstPage: 1,
      ),
      DivisionEntry(
        division: Division.juz,
        number: 2,
        firstAyah: _at('hafs:2:1'),
        firstPage: 2,
      ),
    ]);
    expect(
      [for (final hizb in index.divisions(Division.hizb)) hizb.firstPage],
      [1, 1, 2, 4],
    );
    expect(
      [for (final rub in index.divisions(Division.rub)) '${rub.firstAyah}'],
      [
        'hafs:1:1',
        'hafs:1:2',
        'hafs:1:3',
        'hafs:1:4',
        'hafs:2:1',
        'hafs:2:2',
        'hafs:2:3',
        'hafs:3:1',
      ],
    );
    expect(
      [for (final page in index.divisions(Division.page)) page.firstPage],
      [1, 2, 3, 4],
    );
  });

  test('gives the position of an address', () async {
    final index = await loaded();

    expect(
      index.positionOf(_at('hafs:2:3:1')),
      QuranPosition(
        address: _at('hafs:2:3'),
        surah: 2,
        juz: 2,
        hizb: 3,
        rub: 7,
        page: 3,
      ),
    );
    expect(
      index.positionOf(_at('hafs:1:3')),
      QuranPosition(
        address: _at('hafs:1:3'),
        surah: 1,
        juz: 1,
        hizb: 2,
        rub: 3,
        page: 1,
      ),
    );
  });

  test('gives the page breaks inside a surah crossing pages', () async {
    final index = await loaded();

    expect(
      [for (final page in index.pageStartsIn(1)) '${page.firstAyah}'],
      ['hafs:1:1', 'hafs:1:4'],
    );
    expect(index.firstPage(2), 2);
    expect([for (final page in index.pageStartsIn(2)) page.number], [3]);
    expect([for (final page in index.pageStartsIn(3)) page.number], [4]);
  });

  test('lists the sajda ayat', () async {
    final index = await loaded();

    expect(index.sajdas, [_at('hafs:1:2'), _at('hafs:2:3')]);
    expect(index.isSajda(_at('hafs:2:3:1')), isTrue);
    expect(index.isSajda(_at('hafs:2:2')), isFalse);
  });

  test('a division that does not start at the first ayah fails', () async {
    final result = await load(
      divisions: [
        for (final division in defaultSyntheticDivisions)
          if (division.kind != 'juz') division,
        const SyntheticDivision('juz', 1, 2, 1),
      ],
    );

    expect(
      result,
      isA<Failure<PackQuranIndexRepository>>().having(
        (f) => f.error,
        'error',
        isA<PackInconsistent>(),
      ),
    );
  });

  test('lists no surah while the pack serves no text', () async {
    var serving = true;
    final index = switch (await load(serving: () => serving)) {
      Ok(:final value) => value,
      Failure(:final error) => throw error,
    };
    expect(index.surahs, hasLength(3));

    serving = false;

    expect(index.surahs, isEmpty);
    expect(index.surahCount, 3);
    expect(index.positionOf(_at('hafs:2:3')).page, 3);
  });
}
