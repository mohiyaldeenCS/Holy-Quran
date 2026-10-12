import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/data/models/pack_manifest_json.dart';
import 'package:holyquran/data/repositories/local_pack_repository.dart';
import 'package:holyquran/data/repositories/pack_repository.dart';
import 'package:holyquran/data/repositories/tafsir_repository.dart';
import 'package:holyquran/data/services/daos/settings_dao.dart';
import 'package:holyquran/data/services/manifest_signature.dart';
import 'package:holyquran/data/services/pack_file_service.dart';
import 'package:holyquran/data/services/user_database.dart';
import 'package:holyquran/domain/models/installed_pack.dart';
import 'package:holyquran/domain/models/pack_failure.dart';
import 'package:holyquran/domain/models/pack_integrity.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/tafsir_position.dart';
import 'package:holyquran/domain/models/verified_pack.dart';
import 'package:holyquran/utils/result.dart';

import '../../../testing/fakes/fake_pack_install_repository.dart';
import '../../../testing/fakes/fake_pack_integrity_repository.dart';
import '../../../testing/fakes/fake_quran_index_repository.dart';
import '../../../testing/packs/synthetic_files.dart';
import '../../../testing/packs/synthetic_pack.dart';
import '../../../testing/packs/synthetic_tafsir_pack.dart';

// Every string is synthetic. The structure is that of the default synthetic
// text pack: surahs of 4, 3 and 1 ayat.

/// Verifies packs on the disk and counts the directories it was asked for.
/// While [gate] is set, each check waits for it; [error] replaces the
/// outcome.
final class _CountingVerifier implements PackRepository {
  final _packs = const LocalPackRepository(
    files: PackFileService(),
    signatures: SignatureNotConfigured(),
  );
  final verified = <String>[];
  Completer<void>? gate;
  Exception? error;

  @override
  Future<Result<VerifiedPack>> verify(String directory) async {
    verified.add(directory);
    await gate?.future;
    if (error case final error?) return Failure(error);
    return _packs.verify(directory);
  }
}

final class _FailingDao extends SettingsDao {
  _FailingDao(super.attachedDatabase);

  @override
  Future<void> write(
    String key,
    StoredSetting value, {
    required int updatedAt,
  }) async => throw const FormatException('synthetic failure');
}

QuranAddress _at(int surah, int ayah) => QuranAddress('hafs', surah, ayah);

InstalledPack _installed(Directory directory, Map<String, Object?> manifest) =>
    InstalledPack(
      manifest: switch (parsePackManifest(
        utf8.encode(jsonEncode(manifest)),
        pack: directory.path,
      )) {
        Ok(:final value) => value,
        Failure(:final error) => throw error,
      },
      directory: directory.path,
      previousVersion: null,
    );

T _ok<T>(Result<T> result) => switch (result) {
  Ok(:final value) => value,
  Failure(:final error) => throw TestFailure('failed with $error'),
};

Matcher _failsWith<T extends Exception>([Matcher? error]) =>
    isA<Failure<Object?>>().having(
      (f) => f.error,
      'error',
      error == null ? isA<T>() : allOf(isA<T>(), error),
    );

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Directory root;
  late UserDatabase db;
  late FakePackInstallRepository installs;
  late FakePackIntegrityRepository integrity;
  late _CountingVerifier verifier;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('tafsir_repository_test');
    db = UserDatabase(NativeDatabase.memory());
    installs = FakePackInstallRepository();
    integrity = FakePackIntegrityRepository();
    verifier = _CountingVerifier();
  });

  tearDown(() async {
    integrity.dispose();
    installs.dispose();
    await db.close();
    await root.delete(recursive: true);
  });

  Future<LocalTafsirRepository> repository({SettingsDao? settings}) async {
    final repository = _ok(
      await LocalTafsirRepository.load(
        installs: installs,
        integrity: integrity,
        verifier: verifier,
        structure: FakeQuranIndexRepository.synthetic(),
        settings: settings ?? SettingsDao(db),
      ),
    );
    addTearDown(repository.dispose);
    return repository;
  }

  Future<(SyntheticTafsirPack, InstalledPack)> install({
    SyntheticTafsirFault? fault,
    String id = 'synthetic-tafsir',
    int version = 1,
  }) async {
    final pack = await buildSyntheticTafsirPack(
      root,
      fault: fault,
      id: id,
      version: version,
    );
    final installed = _installed(pack.directory, pack.manifest);
    installs.installed = [
      for (final other in installs.installed)
        if (other.id != id) other,
      installed,
    ];
    return (pack, installed);
  }

  Future<TafsirPosition> positionAt(
    TafsirRepository repository,
    QuranAddress ayah,
  ) async => _ok(await repository.positionAt('synthetic-tafsir', ayah));

  group('passages', () {
    test('every ayah has its passage or none', () async {
      final (pack, _) = await install();
      final tafsir = await repository();
      final structure = FakeQuranIndexRepository.synthetic();

      for (var surah = 1; surah <= structure.surahCount; surah++) {
        for (var ayah = 1; ayah <= structure.ayahCount(surah); ayah++) {
          final position = await positionAt(tafsir, _at(surah, ayah));
          final stored = [
            for (final (index, passage) in pack.passages.indexed)
              if (passage.surah == surah &&
                  passage.firstAyah <= ayah &&
                  ayah <= passage.lastAyah)
                (index + 1, passage),
          ];
          expect(position.ayah, _at(surah, ayah));
          switch (stored) {
            case []:
              expect(position.passage, isNull, reason: '$surah:$ayah');
            case [(final number, final passage)]:
              expect(position.passage!.number, number);
              expect(
                position.passage!.range.start,
                _at(surah, passage.firstAyah),
              );
              expect(position.passage!.range.end, _at(surah, passage.lastAyah));
            default:
              fail('the synthetic passages overlap');
          }
        }
      }
      expect((await positionAt(tafsir, _at(1, 4))).passage, isNull);
    });

    test('passage bytes and book facts equal the pack\'s', () async {
      final (pack, _) = await install();
      final tafsir = await repository();

      for (final stored in pack.passages) {
        final position = await positionAt(
          tafsir,
          _at(stored.surah, stored.lastAyah),
        );
        expect(
          utf8.encode(position.passage!.text.verbatim),
          utf8.encode(stored.text),
        );
      }
      final book = _ok(await tafsir.book('synthetic-tafsir'));
      expect(utf8.encode(book.title.verbatim), utf8.encode(pack.book.title));
      expect(utf8.encode(book.author.verbatim), utf8.encode(pack.book.author));
      expect(
        utf8.encode(book.publisher!.verbatim),
        utf8.encode(pack.book.publisher!),
      );
      expect(book.edition, isNull);
      expect(
        utf8.encode(book.editor!.verbatim),
        utf8.encode(pack.book.editor!),
      );
    });

    test('an address that is not an ayah fails without disabling', () async {
      await install();
      final tafsir = await repository();

      for (final address in [
        QuranAddress('hafs', 1, 1, 1),
        QuranAddress('warsh', 1, 1),
        _at(1, 5),
        _at(4, 1),
      ]) {
        expect(
          await tafsir.positionAt('synthetic-tafsir', address),
          _failsWith<AddressNotInPack>(
            isA<AddressNotInPack>()
                .having((e) => e.pack, 'pack', 'synthetic-tafsir')
                .having((e) => e.address, 'address', address),
          ),
        );
      }
      expect((await positionAt(tafsir, _at(1, 1))).passage, isNotNull);
      expect(integrity.stateOf('synthetic-tafsir'), isA<IntegrityOk>());
    });

    test('a pack that is not installed fails', () async {
      final tafsir = await repository();

      expect(
        await tafsir.positionAt('synthetic-tafsir', _at(1, 1)),
        _failsWith<TafsirNotInstalled>(),
      );
      expect(
        await tafsir.book('synthetic-tafsir'),
        _failsWith<TafsirNotInstalled>(),
      );
      expect(verifier.verified, isEmpty);
    });
  });

  group('navigation', () {
    test('a ranged passage is reached once, forward and back', () async {
      await install();
      final tafsir = await repository();

      final forward = <QuranAddress>[];
      QuranAddress? at = _at(1, 1);
      while (at != null) {
        forward.add(at);
        at = (await positionAt(tafsir, at)).next;
      }
      expect(forward, [_at(1, 1), _at(1, 4), _at(2, 1), _at(2, 2), _at(3, 1)]);

      final back = <QuranAddress>[];
      at = _at(3, 1);
      while (at != null) {
        back.add(at);
        at = (await positionAt(tafsir, at)).previous;
      }
      expect(back, forward.reversed);
    });

    test('an ayah inside a passage steps past its whole range', () async {
      await install();
      final tafsir = await repository();

      final middle = await positionAt(tafsir, _at(1, 2));
      expect(middle.passage!.number, 1);
      expect(middle.previous, isNull);
      expect(middle.next, _at(1, 4));

      final last = await positionAt(tafsir, _at(2, 3));
      expect(last.passage!.number, 3);
      expect(last.previous, _at(2, 1));
      expect(last.next, _at(3, 1));
    });

    test('steps cross surahs and stop at the ends of the Quran', () async {
      await install();
      final tafsir = await repository();

      final first = await positionAt(tafsir, _at(1, 1));
      expect(first.previous, isNull);

      final endOfSurah = await positionAt(tafsir, _at(1, 4));
      expect(endOfSurah.passage, isNull);
      expect(endOfSurah.previous, _at(1, 1));
      expect(endOfSurah.next, _at(2, 1));

      final startOfSurah = await positionAt(tafsir, _at(2, 1));
      expect(startOfSurah.previous, _at(1, 4));

      final last = await positionAt(tafsir, _at(3, 1));
      expect(last.previous, _at(2, 2));
      expect(last.next, isNull);
    });

    test('ayat without passages step one at a time', () async {
      final pack = await buildSyntheticTafsirPack(
        root,
        passages: const [SyntheticPassage(2, 2, 3, 'Synthetic passage')],
      );
      installs.installed = [_installed(pack.directory, pack.manifest)];
      final tafsir = await repository();

      final first = await positionAt(tafsir, _at(1, 1));
      expect(first.passage, isNull);
      expect(first.next, _at(1, 2));

      final beforeRange = await positionAt(tafsir, _at(2, 1));
      expect(beforeRange.next, _at(2, 2));

      final last = await positionAt(tafsir, _at(3, 1));
      expect(last.passage, isNull);
      expect(last.previous, _at(2, 2));
    });
  });

  group('checks', () {
    test('a pack is verified once per session and reported ok', () async {
      final (_, installed) = await install();
      final tafsir = await repository();

      await Future.wait([
        tafsir.book('synthetic-tafsir'),
        tafsir.positionAt('synthetic-tafsir', _at(1, 1)),
        tafsir.positionAt('synthetic-tafsir', _at(2, 2)),
      ]);
      await tafsir.book('synthetic-tafsir');

      expect(verifier.verified, [installed.directory]);
      expect(integrity.reports, hasLength(1));
      expect(integrity.reports.single.state, isA<IntegrityOk>());
      expect(integrity.reports.single.version, 1);
    });

    test('a file that fails its hash serves nothing', () async {
      final (pack, installed) = await install();
      final bytes = await pack.file.readAsBytes();
      bytes[bytes.length - 1] ^= 1;
      await pack.file.writeAsBytes(bytes);
      final tafsir = await repository();

      final failure = isA<FileHashMismatch>().having(
        (e) => e.pack,
        'pack',
        'synthetic-tafsir',
      );
      expect(await tafsir.book('synthetic-tafsir'), _failsWith(failure));
      expect(
        await tafsir.positionAt('synthetic-tafsir', _at(1, 1)),
        _failsWith(failure),
      );
      expect(verifier.verified, [installed.directory]);
      expect(
        integrity.stateOf('synthetic-tafsir'),
        isA<IntegrityFailed>().having((s) => s.reason, 'reason', failure),
      );
      expect(integrity.reports.single.version, 1);
    });

    for (final (fault, failure) in [
      (SyntheticTafsirFault.wrongPassageCount, isA<PackInconsistent>()),
      (SyntheticTafsirFault.reversedRange, isA<PackInconsistent>()),
      (SyntheticTafsirFault.passageOutsideText, isA<PackInconsistent>()),
      (SyntheticTafsirFault.overlappingPassages, isA<PackInconsistent>()),
      (SyntheticTafsirFault.twoBookRows, isA<PackInconsistent>()),
      (SyntheticTafsirFault.leadingBom, isA<PackInconsistent>()),
    ]) {
      test('a pack with ${fault.name} serves nothing', () async {
        await install(fault: fault);
        final tafsir = await repository();
        final named = allOf(
          failure,
          isA<PackFailure>().having((e) => e.pack, 'pack', 'synthetic-tafsir'),
        );

        expect(
          await tafsir.positionAt('synthetic-tafsir', _at(3, 1)),
          _failsWith(named),
        );
        expect(await tafsir.book('synthetic-tafsir'), _failsWith(named));
        expect(
          integrity.stateOf('synthetic-tafsir'),
          isA<IntegrityFailed>().having((s) => s.reason, 'reason', named),
        );
        expect(verifier.verified, hasLength(1));
      });
    }

    test('a verifier error that is not a pack failure is named', () async {
      await install();
      verifier.error = const FormatException('synthetic failure');
      final tafsir = await repository();

      final failure = isA<ManifestUnreadable>().having(
        (e) => e.pack,
        'pack',
        'synthetic-tafsir',
      );
      expect(await tafsir.book('synthetic-tafsir'), _failsWith(failure));
      expect(
        integrity.stateOf('synthetic-tafsir'),
        isA<IntegrityFailed>().having((s) => s.reason, 'reason', failure),
      );
    });

    test('a passage that fails while reading disables the pack', () async {
      final (pack, installed) = await install();
      final damaged = await buildSyntheticTafsirPack(
        Directory('${root.path}/damaged'),
        passages: [
          for (final (index, passage) in defaultSyntheticPassages.indexed)
            index == 2
                ? SyntheticPassage(
                    passage.surah,
                    passage.firstAyah,
                    passage.lastAyah,
                    '\u{FEFF}${passage.text}',
                  )
                : passage,
        ],
      );
      final tafsir = await repository();
      // The check reads every passage on its own connection; the pack's
      // connection has read none yet when the file changes under it.
      expect(await tafsir.book('synthetic-tafsir'), isA<Ok<Object>>());

      await pack.file.writeAsBytes(await damaged.file.readAsBytes());
      final failure = isA<TextEncodingRejected>()
          .having((e) => e.pack, 'pack', 'synthetic-tafsir')
          .having((e) => e.surah, 'surah', 2)
          .having((e) => e.ayah, 'ayah', 2);

      expect(
        await tafsir.positionAt('synthetic-tafsir', _at(2, 2)),
        _failsWith(failure),
      );
      expect(
        await tafsir.positionAt('synthetic-tafsir', _at(1, 1)),
        _failsWith(failure),
      );
      expect(await tafsir.book('synthetic-tafsir'), _failsWith(failure));
      expect(verifier.verified, [installed.directory]);
      expect(integrity.reports.map((r) => r.state.runtimeType), [
        IntegrityOk,
        IntegrityFailed,
      ]);
    });

    test('passages numbered out of mushaf order are refused', () async {
      final pack = await buildSyntheticTafsirPack(
        root,
        passages: const [
          SyntheticPassage(2, 1, 1, 'Synthetic first'),
          SyntheticPassage(1, 1, 1, 'Synthetic second'),
        ],
      );
      installs.installed = [_installed(pack.directory, pack.manifest)];
      final tafsir = await repository();

      expect(
        await tafsir.positionAt('synthetic-tafsir', _at(1, 1)),
        _failsWith<PackInconsistent>(),
      );
    });

    test('passages beyond the last surah are refused', () async {
      final pack = await buildSyntheticTafsirPack(
        root,
        passages: const [
          SyntheticPassage(1, 1, 1, 'Synthetic passage'),
          SyntheticPassage(4, 1, 1, 'Synthetic passage after the end'),
        ],
      );
      installs.installed = [_installed(pack.directory, pack.manifest)];
      final tafsir = await repository();

      expect(
        await tafsir.book('synthetic-tafsir'),
        _failsWith<PackInconsistent>(),
      );
    });

    test('a pack of another riwaya is refused', () async {
      final pack = await buildSyntheticTafsirPack(root);
      final manifest = {...pack.manifest, 'riwaya': 'warsh'};
      await writeManifest(pack.directory, manifest);
      installs.installed = [_installed(pack.directory, manifest)];
      final tafsir = await repository();

      expect(
        await tafsir.book('synthetic-tafsir'),
        _failsWith<PackInconsistent>(),
      );
      expect(integrity.stateOf('synthetic-tafsir'), isA<IntegrityFailed>());
    });
  });

  group('installed packs', () {
    test('lists tafsir packs only and follows the installer', () async {
      final text = await buildSyntheticPack(root);
      installs.installed = [_installed(text.directory, text.manifest)];
      final tafsir = await repository();
      var notified = 0;
      tafsir.addListener(() => notified++);
      expect(tafsir.installed, isEmpty);

      final (_, installed) = await install();
      expect(tafsir.installed.map((p) => p.directory), [installed.directory]);
      expect(notified, 1);

      installs.installed = [...installs.installed];
      expect(notified, 1);
    });

    test('a removed pack serves nothing; a new version is checked', () async {
      final (_, first) = await install();
      final tafsir = await repository();
      await positionAt(tafsir, _at(1, 1));

      installs.installed = [];
      expect(tafsir.installed, isEmpty);
      expect(
        await tafsir.positionAt('synthetic-tafsir', _at(1, 1)),
        _failsWith<TafsirNotInstalled>(),
      );

      final (_, second) = await install(version: 2);
      expect((await positionAt(tafsir, _at(1, 1))).passage, isNotNull);
      expect(verifier.verified, [first.directory, second.directory]);
      expect(integrity.reports.map((r) => (r.state.runtimeType, r.version)), [
        (IntegrityOk, 1),
        (IntegrityOk, 2),
      ]);
    });
  });

  group('while a check runs', () {
    test('a pack removed is not reported and serves nothing', () async {
      final (pack, _) = await install();
      final tafsir = await repository();
      verifier.gate = Completer();

      final reading = tafsir.positionAt('synthetic-tafsir', _at(1, 1));
      await pumpEventQueue();
      installs.installed = [];
      await pack.directory.delete(recursive: true);
      verifier.gate!.complete();

      expect(await reading, _failsWith<TafsirNotInstalled>());
      expect(integrity.reports, isEmpty);
      expect(verifier.verified, hasLength(1));
    });

    test('a repository disposed reports nothing and checks once', () async {
      await install();
      final tafsir = _ok(
        await LocalTafsirRepository.load(
          installs: installs,
          integrity: integrity,
          verifier: verifier,
          structure: FakeQuranIndexRepository.synthetic(),
          settings: SettingsDao(db),
        ),
      );
      verifier.gate = Completer();

      final reading = tafsir.positionAt('synthetic-tafsir', _at(1, 1));
      await pumpEventQueue();
      tafsir.dispose();
      verifier.gate!.complete();

      expect(await reading, _failsWith<TafsirNotInstalled>());
      expect(integrity.reports, isEmpty);
      expect(verifier.verified, hasLength(1));
    });
  });

  group('default tafsir', () {
    test('is none until one is chosen', () async {
      await install();
      expect((await repository()).defaultTafsir, isNull);
    });

    test('persists across sessions and notifies', () async {
      await install();
      final first = await repository();
      var notified = 0;
      first.addListener(() => notified++);

      expect(await first.setDefaultTafsir('synthetic-tafsir'), isA<Ok<void>>());
      expect(first.defaultTafsir, 'synthetic-tafsir');
      expect(notified, 1);

      final second = await repository();
      expect(second.defaultTafsir, 'synthetic-tafsir');
    });

    test('must be installed', () async {
      await install();
      final tafsir = await repository();

      expect(
        await tafsir.setDefaultTafsir('synthetic-missing'),
        _failsWith<TafsirNotInstalled>(),
      );
      expect(tafsir.defaultTafsir, isNull);
    });

    test('reads as none while the chosen pack is not installed', () async {
      final (_, installed) = await install();
      final tafsir = await repository();
      _ok(await tafsir.setDefaultTafsir('synthetic-tafsir'));

      installs.installed = [];
      expect(tafsir.defaultTafsir, isNull);
      installs.installed = [installed];
      expect(tafsir.defaultTafsir, 'synthetic-tafsir');
    });

    test('a write that fails is returned', () async {
      await install();
      final tafsir = await repository(settings: _FailingDao(db));
      var notified = 0;
      tafsir.addListener(() => notified++);

      expect(
        await tafsir.setDefaultTafsir('synthetic-tafsir'),
        _failsWith<FormatException>(),
      );
      expect(tafsir.defaultTafsir, isNull);
      expect(notified, 0);
    });
  });
}
