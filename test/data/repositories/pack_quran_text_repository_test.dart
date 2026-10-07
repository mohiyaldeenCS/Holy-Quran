import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/data/models/pack_manifest_json.dart';
import 'package:holyquran/data/repositories/local_pack_repository.dart';
import 'package:holyquran/data/repositories/pack_quran_text_repository.dart';
import 'package:holyquran/data/services/manifest_signature.dart';
import 'package:holyquran/data/services/pack_database.dart';
import 'package:holyquran/data/services/pack_file_service.dart';
import 'package:holyquran/domain/models/edition_map.dart';
import 'package:holyquran/domain/models/pack_failure.dart';
import 'package:holyquran/domain/models/pack_manifest.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/surah_info.dart';
import 'package:holyquran/domain/models/verified_pack.dart';
import 'package:holyquran/domain/models/word_span.dart';
import 'package:holyquran/utils/result.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../../testing/packs/raw_pack.dart';
import '../../../testing/packs/synthetic_pack.dart';

// Every string is synthetic; non-ASCII characters are written as escapes.

const _id = 'synthetic-text';

QuranAddress _at(String address) => QuranAddress.parse(address);

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp(
      'pack_quran_text_repository_test',
    );
  });
  tearDown(() => root.delete(recursive: true));

  /// The repository over [pack] without verifying its files, so that a
  /// defect the file hash would catch reaches the reading checks.
  PackQuranTextRepository unverified(SyntheticPack pack) {
    final manifest =
        (parsePackManifest(
                  pack.manifestFile.readAsBytesSync(),
                  pack: pack.directory.path,
                )
                as Ok<PackManifest>)
            .value;
    final database = PackDatabase.open(pack.textFile.path, formatVersion: 1);
    addTearDown(database.close);
    return PackQuranTextRepository(
      pack: VerifiedPack(
        directory: pack.directory.path,
        manifest: manifest,
        signatureChecked: false,
      ),
      database: database,
    );
  }

  Matcher fails<T extends PackFailure>([
    Object? Function(T failure)? feature,
    Object? expected,
  ]) => isA<Failure<Object?>>().having(
    (failure) => failure.error,
    'error',
    feature == null
        ? isA<T>().having((f) => f.pack, 'pack', _id)
        : isA<T>()
              .having((f) => f.pack, 'pack', _id)
              .having(feature, 'failure', expected),
  );

  T ok<T>(Result<T> result) => switch (result) {
    Ok(:final value) => value,
    Failure(:final error) => fail('$error'),
  };

  group('a valid pack', () {
    late SyntheticPack pack;
    late PackQuranTextRepository repository;

    setUp(() async {
      pack = await buildSyntheticPack(root);
      repository = unverified(pack);
    });

    test('names its riwaya and font', () async {
      expect(repository.riwaya, 'hafs');
      expect(repository.font.family, 'Amiri Quran');
      expect(repository.font.version, '1.003');
      expect(
        repository.font.sha256,
        (pack.manifest['font']! as Map<String, Object?>)['sha256'],
      );
    });

    test('lists its surahs', () async {
      final surahs = ok(await repository.surahs());
      expect(surahs.map((s) => s.number), [1, 2, 3]);
      expect(surahs.map((s) => s.name.verbatim), [
        for (final surah in pack.surahs) surah.name,
      ]);
      expect(surahs.map((s) => s.ayahCount), [4, 3, 1]);
    });

    test('gives every ayah as its stored bytes', () async {
      final raw = RawPack.open(pack.textFile);
      addTearDown(raw.close);
      for (var surah = 1; surah <= 3; surah++) {
        for (final (number, bytes) in raw.ayat(surah)) {
          final text = ok(
            await repository.ayahText(QuranAddress('hafs', surah, number)),
          );
          expect(utf8.encode(text.verbatim), bytes, reason: '$surah:$number');
        }
      }
    });

    test('gives the basmala, or null where there is none', () async {
      expect(
        ok(await repository.basmala(1))!.verbatim,
        'Synthetic opening line',
      );
      expect(ok(await repository.basmala(2)), isNull);
      expect(ok(await repository.basmala(3)), isNotNull);
    });

    test('gives word spans', () async {
      expect(ok(await repository.words(_at('hafs:2:3'))), const [
        WordSpan(number: 1, start: 0, end: 9),
        WordSpan(number: 2, start: 10, end: 14),
        WordSpan(number: 3, start: 15, end: 21),
      ]);
      expect(
        ok(
          await repository.words(_at('hafs:1:4')),
        ).map((w) => (w.start, w.end)),
        pack.surahs[0].ayat[3].spans,
      );
    });

    test('builds the edition map in its riwaya', () async {
      final map = ok(await repository.editionMap());
      expect(map.edition, 'synthetic-edition');
      expect(
        {for (final d in Division.values) d: map.count(d)},
        {Division.juz: 2, Division.hizb: 4, Division.rub: 8, Division.page: 4},
      );
      expect(map.startOf(Division.juz, 2), _at('hafs:2:1'));
      expect(map.startOf(Division.page, 3), _at('hafs:2:2'));
      expect(map.numberAt(Division.juz, _at('hafs:1:4')), 1);
      expect(map.numberAt(Division.juz, _at('hafs:2:1')), 2);
      expect(map.numberAt(Division.juz, _at('hafs:3:1')), 2);
      expect(map.numberAt(Division.hizb, _at('hafs:1:2')), 1);
      expect(map.numberAt(Division.hizb, _at('hafs:1:3')), 2);
      expect(map.numberAt(Division.rub, _at('hafs:2:3')), 7);
      expect(map.numberAt(Division.page, _at('hafs:1:3')), 1);
      expect(map.numberAt(Division.page, _at('hafs:1:4')), 2);
      expect(map.numberAt(Division.page, _at('hafs:2:1')), 2);
      expect(map.numberAt(Division.page, _at('hafs:2:2:1')), 3);
      expect(map.numberAt(Division.page, _at('hafs:3:1')), 4);
      expect(map.sajdas, {_at('hafs:1:2'), _at('hafs:2:3')});
      expect(map.isSajda(_at('hafs:1:2')), isTrue);
      expect(map.isSajda(_at('hafs:2:3:2')), isTrue);
      expect(map.isSajda(_at('hafs:1:3')), isFalse);
      expect(identical(ok(await repository.editionMap()), map), isTrue);
    });

    test('contains its ayat and words, and nothing else', () async {
      for (final address in [
        'hafs:1:1',
        'hafs:1:4',
        'hafs:2:3',
        'hafs:3:1',
        'hafs:1:1:3',
        'hafs:2:2:3',
      ]) {
        expect(
          ok(await repository.contains(_at(address))),
          isTrue,
          reason: address,
        );
      }
      for (final address in [
        'hafs:1:5',
        'hafs:4:1',
        'hafs:2:4',
        'hafs:1:1:4',
        'hafs:2:2:4',
        'warsh:1:1',
      ]) {
        expect(
          ok(await repository.contains(_at(address))),
          isFalse,
          reason: address,
        );
      }
    });

    test('refuses an address it does not hold, and stays enabled', () async {
      for (final address in [
        'warsh:1:1',
        'hafs:1:5',
        'hafs:4:1',
        'hafs:1:1:1',
      ]) {
        final notInPack = fails<AddressNotInPack>(
          (f) => f.address,
          _at(address),
        );
        expect(
          await repository.ayahText(_at(address)),
          notInPack,
          reason: address,
        );
        expect(
          await repository.words(_at(address)),
          notInPack,
          reason: address,
        );
      }
      expect(
        await repository.basmala(4),
        fails<AddressNotInPack>((f) => f.address, _at('hafs:4:1')),
      );
      await expectLater(repository.basmala(0), throwsArgumentError);
      expect(ok(await repository.ayahText(_at('hafs:1:1'))), isNotNull);
    });
  });

  group('a surah whose digest differs', () {
    test('fails its first read, then disables the pack', () async {
      final repository = unverified(
        await buildSyntheticPack(root, fault: SyntheticFault.wrongSurahHash),
      );
      expect(ok(await repository.ayahText(_at('hafs:2:1'))), isNotNull);
      expect(
        await repository.ayahText(_at('hafs:1:2')),
        fails<SurahHashMismatch>((f) => f.surah, 1),
      );
      final disabled = fails<PackDisabled>();
      expect(await repository.ayahText(_at('hafs:1:2')), disabled);
      expect(await repository.ayahText(_at('hafs:2:1')), disabled);
      expect(await repository.basmala(3), disabled);
      expect(await repository.words(_at('hafs:2:1')), disabled);
      expect(await repository.surahs(), disabled);
      expect(await repository.editionMap(), disabled);
      expect(await repository.ayahText(_at('warsh:1:1')), disabled);
      expect(await repository.contains(_at('hafs:2:1')), disabled);
      expect(await repository.contains(_at('hafs:9:1')), disabled);
    });

    for (final (name, read) in [
      ('basmala', (PackQuranTextRepository r) => r.basmala(1)),
      ('words', (PackQuranTextRepository r) => r.words(_at('hafs:1:3'))),
    ]) {
      test('is caught by a first read of its $name', () async {
        final repository = unverified(
          await buildSyntheticPack(root, fault: SyntheticFault.wrongSurahHash),
        );
        expect(await read(repository), fails<SurahHashMismatch>());
      });
    }

    test(
      'is caught when a byte changed and the file was not verified',
      () async {
        final repository = unverified(
          await buildSyntheticPack(root, fault: SyntheticFault.flippedByte),
        );
        expect(
          await repository.ayahText(_at('hafs:1:4')),
          fails<SurahHashMismatch>((f) => f.surah, 1),
        );
      },
    );
  });

  test(
    'a leading U+FEFF in any ayah of a surah fails its first read',
    () async {
      final repository = unverified(
        await buildSyntheticPack(root, fault: SyntheticFault.leadingBom),
      );
      expect(
        await repository.ayahText(_at('hafs:1:3')),
        fails<TextEncodingRejected>((f) => (f.surah, f.ayah), (1, 1)),
      );
      expect(await repository.ayahText(_at('hafs:2:1')), fails<PackDisabled>());
    },
  );

  test('a leading U+FEFF in a surah name fails the surah list', () async {
    final repository = unverified(
      await buildSyntheticPack(
        root,
        surahs: const [
          SyntheticSurah(
            name: '\u{FEFF}Synthetic surah',
            ayat: [SyntheticAyah('Synthetic ayah')],
          ),
        ],
        divisions: const [],
        sajdas: const [],
      ),
    );
    expect(
      await repository.surahs(),
      fails<TextEncodingRejected>((f) => (f.surah, f.ayah), (1, null)),
    );
    expect(await repository.surahs(), fails<PackDisabled>());
  });

  group('word spans', () {
    /// A pack whose ayah 2:2 has the [words] given, its text unchanged.
    Future<PackQuranTextRepository> withWords(List<(int, int)> words) async {
      final surahs = [...defaultSyntheticSurahs];
      final second = surahs[1];
      surahs[1] = SyntheticSurah(
        name: second.name,
        revelationPlace: second.revelationPlace,
        revelationOrder: second.revelationOrder,
        ayat: [
          second.ayat[0],
          SyntheticAyah(second.ayat[1].text, words: words),
          second.ayat[2],
        ],
      );
      return unverified(await buildSyntheticPack(root, surahs: surahs));
    }

    test('that are valid are given, also around a surrogate pair', () async {
      final repository = await withWords(const [(0, 2), (3, 5), (6, 8)]);
      expect(ok(await repository.words(_at('hafs:2:2'))), const [
        WordSpan(number: 1, start: 0, end: 2),
        WordSpan(number: 2, start: 3, end: 5),
        WordSpan(number: 3, start: 6, end: 8),
      ]);
      expect(ok(await repository.contains(_at('hafs:2:2:3'))), isTrue);
      expect(ok(await repository.contains(_at('hafs:2:2:4'))), isFalse);
    });

    final faults = {
      'overlapping': (
        const [(0, 2), (1, 5), (6, 8)],
        'hafs:2:2: word 2 overlaps the word before: [1, 5)',
      ),
      'out of order': (
        const [(3, 5), (0, 2), (6, 8)],
        'hafs:2:2: word 2 overlaps the word before: [0, 2)',
      ),
      'empty': (
        const [(0, 2), (3, 3), (6, 8)],
        'hafs:2:2: word 2 is empty or reversed: [3, 3)',
      ),
      'reversed': (
        const [(0, 2), (5, 3), (6, 8)],
        'hafs:2:2: word 2 is empty or reversed: [5, 3)',
      ),
      'negative': (
        const [(-1, 2), (3, 5), (6, 8)],
        'hafs:2:2: word 1 is outside the ayah or splits a character: [-1, 2)',
      ),
      'past the end of the ayah': (
        const [(0, 2), (3, 5), (6, 9)],
        'hafs:2:2: word 3 is outside the ayah or splits a character: [6, 9)',
      ),
      'splitting a surrogate pair': (
        const [(0, 2), (3, 4), (6, 8)],
        'hafs:2:2: word 2 is outside the ayah or splits a character: [3, 4)',
      ),
    };
    for (final MapEntry(key: name, value: (words, reason)) in faults.entries) {
      test(
        '$name fail the first read of the surah, then disable the pack',
        () async {
          final repository = await withWords(words);
          expect(ok(await repository.ayahText(_at('hafs:1:1'))), isNotNull);
          expect(
            await repository.ayahText(_at('hafs:2:1')),
            fails<PackInconsistent>((f) => f.reason, reason),
          );
          expect(
            await repository.words(_at('hafs:1:1')),
            fails<PackDisabled>(),
          );
        },
      );
    }

    test('numbered with a gap fail, as checked by contains too', () async {
      final pack = await buildSyntheticPack(root);
      final writable = sqlite3.open(pack.textFile.path);
      writable.execute(
        'UPDATE word SET number = 5 WHERE surah = 2 AND ayah = 2 AND number = 3',
      );
      writable.close();
      final repository = unverified(pack);
      expect(
        await repository.contains(_at('hafs:2:2:1')),
        fails<PackInconsistent>(
          (f) => f.reason,
          'hafs:2:2: word 3 is numbered 5: [6, 8)',
        ),
      );
      expect(await repository.contains(_at('hafs:1:1')), fails<PackDisabled>());
    });

    test('are checked by contains before a word is found', () async {
      final repository = unverified(
        await buildSyntheticPack(root, fault: SyntheticFault.overlappingSpans),
      );
      expect(ok(await repository.contains(_at('hafs:1:1'))), isTrue);
      expect(
        await repository.contains(_at('hafs:1:1:2')),
        fails<PackInconsistent>(
          (f) => f.reason,
          'hafs:1:1: word 2 overlaps the word before: [8, 14)',
        ),
      );
    });
  });

  group('counts that differ from the stored rows', () {
    test('fail the first read, then disable the pack', () async {
      final repository = unverified(
        await buildSyntheticPack(root, fault: SyntheticFault.wrongCounts),
      );
      expect(
        await repository.ayahText(_at('hafs:1:1')),
        fails<PackInconsistent>(
          (f) => f.reason,
          'counts.ayat is 9; the pack holds 8',
        ),
      );
      expect(await repository.surahs(), fails<PackDisabled>());
    });

    test('are checked even when only the edition map is read', () async {
      final repository = unverified(
        await buildSyntheticPack(root, fault: SyntheticFault.wrongCounts),
      );
      expect(await repository.editionMap(), fails<PackInconsistent>());
    });
  });

  group('divisions', () {
    Future<PackQuranTextRepository> withJuz(
      List<SyntheticDivision> juz,
    ) async => unverified(
      await buildSyntheticPack(
        root,
        divisions: [
          ...juz,
          for (final d in defaultSyntheticDivisions)
            if (d.kind != 'juz') d,
        ],
      ),
    );

    test('out of order fail the edition map and disable the pack', () async {
      final repository = await withJuz(const [
        SyntheticDivision('juz', 1, 2, 1),
        SyntheticDivision('juz', 2, 1, 1),
      ]);
      expect(
        await repository.editionMap(),
        fails<PackInconsistent>(
          (f) => f.reason,
          'juz 2 does not follow the unit before',
        ),
      );
      expect(await repository.surahs(), fails<PackDisabled>());
    });

    test('with a gap in their numbers fail the edition map', () async {
      final repository = await withJuz(const [
        SyntheticDivision('juz', 1, 1, 1),
        SyntheticDivision('juz', 3, 2, 1),
      ]);
      expect(
        await repository.editionMap(),
        fails<PackInconsistent>((f) => f.reason, 'juz 3 is out of sequence'),
      );
    });

    test('may be absent', () async {
      final repository = unverified(
        await buildSyntheticPack(root, divisions: const [], sajdas: const []),
      );
      final map = ok(await repository.editionMap());
      expect(map.count(Division.page), 0);
      expect(map.sajdas, isEmpty);
    });
  });

  test('a pack with no riwaya cannot be read as text', () async {
    final pack = await buildSyntheticPack(root);
    final manifest =
        (parsePackManifest(pack.manifestFile.readAsBytesSync(), pack: 'p')
                as Ok<PackManifest>)
            .value;
    final database = PackDatabase.open(pack.textFile.path, formatVersion: 1);
    addTearDown(database.close);
    expect(
      () => PackQuranTextRepository(
        pack: VerifiedPack(
          directory: pack.directory.path,
          manifest: PackManifest(
            formatVersion: manifest.formatVersion,
            id: manifest.id,
            kind: manifest.kind,
            version: manifest.version,
            changelog: manifest.changelog,
            riwaya: null,
            edition: manifest.edition,
            font: manifest.font,
            sources: manifest.sources,
            files: manifest.files,
            surahSha256: manifest.surahSha256,
            counts: manifest.counts,
            reviews: manifest.reviews,
          ),
          signatureChecked: false,
        ),
        database: database,
      ),
      throwsArgumentError,
    );
  });

  group('open', () {
    VerifiedPack verifiedFrom(SyntheticPack pack, {String? riwaya = 'hafs'}) {
      final manifest =
          (parsePackManifest(pack.manifestFile.readAsBytesSync(), pack: 'p')
                  as Ok<PackManifest>)
              .value;
      return VerifiedPack(
        directory: pack.directory.path,
        manifest: riwaya != null
            ? manifest
            : PackManifest(
                formatVersion: manifest.formatVersion,
                id: manifest.id,
                kind: manifest.kind,
                version: manifest.version,
                changelog: manifest.changelog,
                riwaya: null,
                edition: manifest.edition,
                font: manifest.font,
                sources: manifest.sources,
                files: manifest.files,
                surahSha256: manifest.surahSha256,
                counts: manifest.counts,
                reviews: manifest.reviews,
              ),
        signatureChecked: false,
      );
    }

    test('opens the text file of a pack read-only', () async {
      final pack = await buildSyntheticPack(root);
      final repository = switch (PackQuranTextRepository.open(
        verifiedFrom(pack),
      )) {
        Ok(:final value) => value,
        Failure(:final error) => fail('$error'),
      };
      addTearDown(repository.close);
      expect(
        ok(await repository.ayahText(_at('hafs:3:1'))).verbatim,
        'Synthetic last ayah',
      );
      expect(pack.directory.listSync(), hasLength(2));
    });

    test('a file that is not a text pack, named by the pack id', () async {
      final pack = await buildSyntheticPack(
        root,
        fault: SyntheticFault.walHeader,
      );
      expect(
        PackQuranTextRepository.open(verifiedFrom(pack)),
        fails<UnsupportedPackFormat>((f) => f.formatVersion, 1),
      );
    });

    test('a file that is missing, as a file whose bytes differ', () async {
      final pack = await buildSyntheticPack(
        root,
        fault: SyntheticFault.missingFile,
      );
      expect(
        PackQuranTextRepository.open(verifiedFrom(pack)),
        fails<FileHashMismatch>((f) => f.file, textPackFileName),
      );
      expect(pack.directory.listSync(), hasLength(1));
    });

    test('a pack with no riwaya, without opening its file', () async {
      final pack = await buildSyntheticPack(root);
      expect(
        PackQuranTextRepository.open(verifiedFrom(pack, riwaya: null)),
        fails<UnsupportedPackFormat>(),
      );
    });
  });

  group('through the production path', () {
    /// Verifies, opens and reads every text of the pack built with [fault];
    /// returns the step that failed and its failure, or null.
    Future<(String, PackFailure)?> firstFailure(SyntheticFault? fault) async {
      final pack = await buildSyntheticPack(root, fault: fault);
      const verifier = LocalPackRepository(
        files: PackFileService(),
        signatures: SignatureNotConfigured(),
      );
      final VerifiedPack verified;
      switch (await verifier.verify(pack.directory.path)) {
        case Ok(:final value):
          verified = value;
        case Failure(:final error):
          return ('verify', error as PackFailure);
      }
      final PackQuranTextRepository repository;
      switch (PackQuranTextRepository.open(verified)) {
        case Ok(:final value):
          repository = value;
        case Failure(:final error):
          return ('open', error as PackFailure);
      }
      addTearDown(repository.close);
      final List<SurahInfo> surahs;
      switch (await repository.surahs()) {
        case Ok(:final value):
          surahs = value;
        case Failure(:final error):
          return ('read', error as PackFailure);
      }
      for (final surah in surahs) {
        final reads = [
          await repository.basmala(surah.number),
          for (var ayah = 1; ayah <= surah.ayahCount; ayah++) ...[
            await repository.ayahText(QuranAddress('hafs', surah.number, ayah)),
            await repository.words(QuranAddress('hafs', surah.number, ayah)),
          ],
        ];
        for (final result in reads) {
          if (result case Failure(:final error)) {
            return ('read', error as PackFailure);
          }
        }
      }
      if (await repository.editionMap() case Failure(:final error)) {
        return ('read', error as PackFailure);
      }
      return null;
    }

    test('a valid pack is read through', () async {
      expect(await firstFailure(null), isNull);
    });

    final expected = <SyntheticFault, (String, Matcher)>{
      SyntheticFault.flippedByte: (
        'verify',
        isA<FileHashMismatch>().having((f) => f.file, 'file', textFileName),
      ),
      SyntheticFault.wrongSurahHash: (
        'read',
        isA<SurahHashMismatch>().having((f) => f.surah, 'surah', 1),
      ),
      SyntheticFault.wrongCounts: (
        'read',
        isA<PackInconsistent>().having(
          (f) => f.reason,
          'reason',
          'counts.ayat is 9; the pack holds 8',
        ),
      ),
      SyntheticFault.leadingBom: (
        'read',
        isA<TextEncodingRejected>()
            .having((f) => f.surah, 'surah', 1)
            .having((f) => f.ayah, 'ayah', 1),
      ),
      SyntheticFault.walHeader: ('open', isA<UnsupportedPackFormat>()),
      SyntheticFault.wrongApplicationId: ('open', isA<UnsupportedPackFormat>()),
      SyntheticFault.wrongUserVersion: (
        'open',
        isA<UnsupportedPackFormat>().having(
          (f) => f.formatVersion,
          'formatVersion',
          2,
        ),
      ),
      SyntheticFault.unsupportedFormatVersion: (
        'verify',
        isA<UnsupportedPackFormat>().having(
          (f) => f.formatVersion,
          'formatVersion',
          2,
        ),
      ),
      SyntheticFault.pathInFileName: ('verify', isA<ManifestUnreadable>()),
      SyntheticFault.missingFile: (
        'verify',
        isA<FileHashMismatch>().having((f) => f.file, 'file', textFileName),
      ),
      SyntheticFault.wrongFileSize: (
        'verify',
        isA<FileHashMismatch>().having((f) => f.file, 'file', textFileName),
      ),
      SyntheticFault.overlappingSpans: (
        'read',
        isA<PackInconsistent>().having(
          (f) => f.reason,
          'reason',
          'hafs:1:1: word 2 overlaps the word before: [8, 14)',
        ),
      ),
      SyntheticFault.nonStrictSchema: ('open', isA<UnsupportedPackFormat>()),
    };

    test('every fault has an expected step and failure', () async {
      expect(expected.keys.toSet(), SyntheticFault.values.toSet());
    });

    for (final MapEntry(key: fault, value: (step, failure))
        in expected.entries) {
      test('${fault.name} is refused at $step', () async {
        final (actualStep, actualFailure) = (await firstFailure(fault))!;
        expect(actualStep, step);
        expect(actualFailure, failure);
      });
    }

    test('reading leaves the pack file unchanged', () async {
      final pack = await buildSyntheticPack(root);
      final hash = await fileSha256(pack.textFile);
      final repository = unverified(pack);
      for (final surah in ok(await repository.surahs())) {
        for (var ayah = 1; ayah <= surah.ayahCount; ayah++) {
          ok(
            await repository.ayahText(QuranAddress('hafs', surah.number, ayah)),
          );
        }
      }
      expect(await fileSha256(pack.textFile), hash);
      expect(pack.directory.listSync(), hasLength(2));
    });
  });
}
