import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/data/repositories/local_pack_repository.dart';
import 'package:holyquran/data/repositories/pack_integrity_repository.dart';
import 'package:holyquran/data/services/base_pack_service.dart';
import 'package:holyquran/data/services/manifest_signature.dart';
import 'package:holyquran/data/services/pack_file_service.dart';
import 'package:holyquran/domain/models/pack_failure.dart';
import 'package:holyquran/domain/models/pack_integrity.dart';
import 'package:holyquran/domain/models/verified_pack.dart';

import '../../../testing/packs/synthetic_pack.dart';

const _id = 'synthetic-text';

/// Serves the files of [directory] as the bundled pack synthetic-text/1;
/// with no directory, the app bundles no pack.
final class _DirectoryBundle extends CachingAssetBundle {
  _DirectoryBundle(this.directory);

  Directory? directory;

  @override
  Future<ByteData> load(String key) async {
    const prefix = 'assets/packs/$_id/1/';
    final file = File('${directory?.path}/${key.substring(prefix.length)}');
    if (directory == null || !key.startsWith(prefix) || !file.existsSync()) {
      throw FlutterError('Unable to load asset: "$key".');
    }
    return ByteData.sublistView(await file.readAsBytes());
  }
}

/// Counts the copies, and spoils the text file of the first [spoiled] of
/// them after copying it.
final class _CountingService extends BasePackService {
  _CountingService({
    required super.bundle,
    required super.supportDirectory,
    this.spoiled = 0,
  }) : super(id: _id, version: 1);

  final int spoiled;
  var extracts = 0;

  @override
  Future<void> extract(List<String> names) async {
    await super.extract(names);
    if (++extracts <= spoiled) {
      final file = File('${await directory()}/$textFileName');
      final bytes = file.readAsBytesSync();
      bytes[bytes.length - 1] ^= 0xFF;
      file.writeAsBytesSync(bytes);
    }
  }
}

void main() {
  late Directory root;
  late Directory support;
  late _DirectoryBundle bundle;

  setUp(() async {
    root = await Directory.systemTemp.createTemp(
      'pack_integrity_repository_test',
    );
    support = await Directory('${root.path}/support').create();
    final pack = await buildSyntheticPack(Directory('${root.path}/bundle'));
    bundle = _DirectoryBundle(pack.directory);
  });
  tearDown(() => root.delete(recursive: true));

  const packs = LocalPackRepository(
    files: PackFileService(),
    signatures: SignatureNotConfigured(),
  );

  _CountingService service({int spoiled = 0}) => _CountingService(
    bundle: bundle,
    supportDirectory: () async => support,
    spoiled: spoiled,
  );

  /// A repository over [basePack] whose events are collected in the
  /// returned list.
  (LocalPackIntegrityRepository, List<PackIntegrityEvent>) repository(
    BasePackService basePack,
  ) {
    final integrity = LocalPackIntegrityRepository(
      basePack: basePack,
      verify: packs.verify,
      verifySizes: packs.verifySizes,
      clock: () => DateTime.utc(2026, 10, 12),
    );
    addTearDown(integrity.dispose);
    final events = <PackIntegrityEvent>[];
    integrity.events.listen(events.add);
    return (integrity, events);
  }

  Future<List<String>> states(List<PackIntegrityEvent> events) async {
    await pumpEventQueue();
    return [for (final event in events) '${event.state}'];
  }

  group('the base pack', () {
    test('on first run is copied, checked in full and remembered', () async {
      final basePack = service();
      final (integrity, events) = repository(basePack);

      final verified = await integrity.verifyBasePack();

      expect(verified, isA<VerifiedPack>());
      expect(verified!.directory, await basePack.directory());
      expect(basePack.extracts, 1);
      expect(integrity.stateOf(_id), isA<IntegrityOk>());
      expect(
        await basePack.remembers(
          (await basePack.readBundled(manifestFileName))!,
        ),
        isTrue,
      );
      expect(await states(events), ['ok']);
      expect(events.single.version, 1);
      expect(events.single.at, DateTime.utc(2026, 10, 12));
    });

    test('on a later run is not copied or hashed again', () async {
      await repository(service()).$1.verifyBasePack();
      final basePack = service();
      final (integrity, events) = repository(basePack);

      expect(await integrity.verifyBasePack(), isA<VerifiedPack>());
      expect(basePack.extracts, 0);
      expect(await states(events), ['ok']);
    });

    test('after an update to the bundled pack is copied again', () async {
      await repository(service()).$1.verifyBasePack();
      final updated = await buildSyntheticPack(
        Directory('${root.path}/update'),
        surahs: defaultSyntheticSurahs.take(2).toList(),
        divisions: [
          for (final division in defaultSyntheticDivisions)
            if (division.surah < 3) division,
        ],
      );
      bundle.directory = updated.directory;
      final basePack = service();
      final (integrity, _) = repository(basePack);

      final verified = await integrity.verifyBasePack();

      expect(basePack.extracts, 1);
      expect(verified!.manifest.counts.surahs, 2);
    });

    test('a copy that lost a file is copied again', () async {
      final first = service();
      await repository(first).$1.verifyBasePack();
      File('${await first.directory()}/$textFileName').deleteSync();
      final basePack = service();
      final (integrity, events) = repository(basePack);

      expect(await integrity.verifyBasePack(), isA<VerifiedPack>());
      expect(basePack.extracts, 1);
      expect(await states(events), ['repairing', 'ok']);
    });

    test('a corrupt copy is copied once more, then served', () async {
      final basePack = service(spoiled: 1);
      final (integrity, events) = repository(basePack);

      expect(await integrity.verifyBasePack(), isA<VerifiedPack>());
      expect(basePack.extracts, 2);
      expect(integrity.stateOf(_id), isA<IntegrityOk>());
      expect(await states(events), ['repairing', 'ok']);
    });

    test('a copy corrupt twice fails, and is not remembered', () async {
      final basePack = service(spoiled: 2);
      final (integrity, events) = repository(basePack);

      expect(await integrity.verifyBasePack(), isNull);
      expect(basePack.extracts, 2);
      expect(
        integrity.stateOf(_id),
        isA<IntegrityFailed>().having(
          (state) => state.reason,
          'reason',
          isA<FileHashMismatch>(),
        ),
      );
      expect(
        await basePack.remembers(
          (await basePack.readBundled(manifestFileName))!,
        ),
        isFalse,
      );
      expect(await states(events), ['repairing', startsWith('failed: ')]);
    });

    test(
      'a bundled pack that fails its check fails after two copies',
      () async {
        final broken = await buildSyntheticPack(
          Directory('${root.path}/broken'),
          fault: SyntheticFault.flippedByte,
        );
        bundle.directory = broken.directory;
        final basePack = service();
        final (integrity, _) = repository(basePack);

        expect(await integrity.verifyBasePack(), isNull);
        expect(basePack.extracts, 2);
        expect(integrity.stateOf(_id), isA<IntegrityFailed>());
      },
    );

    test('a bundled manifest that cannot be read fails at once', () async {
      final broken = await buildSyntheticPack(
        Directory('${root.path}/broken'),
        fault: SyntheticFault.pathInFileName,
      );
      bundle.directory = broken.directory;
      final basePack = service();
      final (integrity, _) = repository(basePack);

      expect(await integrity.verifyBasePack(), isNull);
      expect(basePack.extracts, 0);
      expect(
        integrity.stateOf(_id),
        isA<IntegrityFailed>().having(
          (state) => state.reason,
          'reason',
          isA<ManifestUnreadable>(),
        ),
      );
    });

    test('that the app does not bundle is missing', () async {
      bundle.directory = null;
      final basePack = service();
      final (integrity, events) = repository(basePack);

      expect(await integrity.verifyBasePack(), isNull);
      expect(basePack.extracts, 0);
      expect(integrity.stateOf(_id), isA<IntegrityMissing>());
      expect(await states(events), ['missing']);
    });

    test('a copy that cannot be written fails', () async {
      final file = File('${root.path}/not-a-directory')..writeAsStringSync('');
      final basePack = _CountingService(
        bundle: bundle,
        supportDirectory: () async => Directory(file.path),
      );
      final (integrity, _) = repository(basePack);

      expect(await integrity.verifyBasePack(), isNull);
      expect(
        integrity.stateOf(_id),
        isA<IntegrityFailed>().having(
          (state) => state.reason,
          'reason',
          isA<ManifestUnreadable>(),
        ),
      );
    });

    test('forgotten, is copied and checked in full again', () async {
      final (first, _) = repository(service());
      await first.verifyBasePack();
      await first.forgetBasePackCheck();
      final basePack = service();

      expect(await repository(basePack).$1.verifyBasePack(), isNotNull);
      expect(basePack.extracts, 1);
    });
  });

  group('report', () {
    test('notifies and adds an event when the state changes', () async {
      final (integrity, events) = repository(service());
      var notified = 0;
      integrity.addListener(() => notified++);

      integrity.report('synthetic-b', const IntegrityOk(), version: 3);
      integrity.report('synthetic-b', const IntegrityOk(), version: 3);
      integrity.report('synthetic-b', const IntegrityFailed(PackDisabled('b')));
      integrity.report('synthetic-b', const IntegrityFailed(PackDisabled('b')));

      expect(notified, 3);
      expect(await states(events), [
        'ok',
        'failed: PackDisabled(b)',
        'failed: PackDisabled(b)',
      ]);
      expect(events.first.version, 3);
      expect(integrity.stateOf('synthetic-b'), isA<IntegrityFailed>());
    });

    test('a pack nothing reported is missing', () {
      expect(
        repository(service()).$1.stateOf('other'),
        isA<IntegrityMissing>(),
      );
    });

    test('keeps the events made before the log listens', () async {
      final integrity = LocalPackIntegrityRepository(
        basePack: service(),
        verify: packs.verify,
        verifySizes: packs.verifySizes,
      );
      integrity.report('synthetic-b', const IntegrityOk());
      final events = integrity.events.toList();
      integrity.dispose();

      expect([for (final e in await events) e.pack], ['synthetic-b']);
    });
  });
}
