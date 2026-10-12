import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/data/services/installed_packs_store.dart';
import 'package:holyquran/domain/models/install_job.dart';
import 'package:holyquran/utils/result.dart';

const _id = 'synthetic-text';

void main() {
  late Directory support;
  late InstalledPacksStore store;

  setUp(() async {
    support = await Directory.systemTemp.createTemp('installed_packs_test');
    store = InstalledPacksStore(support);
  });

  tearDown(() => support.delete(recursive: true));

  String at(String path) => '${support.path}/$path';

  Future<void> write(String path, String content) async {
    await File(at(path)).create(recursive: true);
    await File(at(path)).writeAsString(content);
  }

  Future<String?> read(String path) async {
    final file = File(at(path));
    return await file.exists() ? file.readAsString() : null;
  }

  bool exists(String path) =>
      FileSystemEntity.typeSync(at(path)) != FileSystemEntityType.notFound;

  Future<Map<String, Object?>> activeJson([String id = _id]) async =>
      jsonDecode((await read('packs/$id/active.json'))!)
          as Map<String, Object?>;

  /// Stages [version] of [id] with one synthetic file and activates it.
  Future<StoredPack> install(int version, {String id = _id}) async {
    await store.prepareStaging(id, version);
    await write('pack-staging/$id/$version/data.bin', 'synthetic $version');
    return switch (await store.activate(id, version)) {
      Ok(:final value) => value,
      Failure(:final error) => throw error,
    };
  }

  group('ids and paths', () {
    test('an id is lower-case letters, digits and hyphens', () {
      for (final id in ['a', 'synthetic-text', '0-a', 'base-hafs-1']) {
        expect(InstalledPacksStore.isValidId(id), isTrue, reason: id);
      }
      for (final id in ['', '-a', 'A', 'a_b', 'a/b', '..', 'a.b', ' a']) {
        expect(InstalledPacksStore.isValidId(id), isFalse, reason: id);
      }
    });

    test('staging and versions sit under the support directory', () {
      expect(
        InstalledPacksStore.stagingRelativePath(_id, 2),
        'pack-staging/$_id/2',
      );
      expect(store.stagingPath(_id, 2), at('pack-staging/$_id/2'));
      expect(store.versionPath(_id, 2), at('packs/$_id/2'));
    });
  });

  group('staging', () {
    test(
      'prepareStaging makes the directory and keeps what is there',
      () async {
        expect(await store.prepareStaging(_id, 1), at('pack-staging/$_id/1'));
        await write('pack-staging/$_id/1/kept.bin', 'synthetic');
        await store.prepareStaging(_id, 1);
        expect(await read('pack-staging/$_id/1/kept.bin'), 'synthetic');
      },
    );

    test(
      'discardStagedFile removes one file, discardStaging the version',
      () async {
        await store.prepareStaging(_id, 1);
        await write('pack-staging/$_id/1/a.bin', 'synthetic a');
        await write('pack-staging/$_id/1/b.bin', 'synthetic b');
        await store.discardStagedFile(_id, 1, 'a.bin');
        await store.discardStagedFile(_id, 1, 'absent.bin');
        expect(exists('pack-staging/$_id/1/a.bin'), isFalse);
        expect(exists('pack-staging/$_id/1/b.bin'), isTrue);
        await store.discardStaging(_id, 1);
        await store.discardStaging(_id, 1);
        expect(exists('pack-staging/$_id/1'), isFalse);
      },
    );

    test('an invalid id is refused before any path is touched', () {
      expect(() => store.prepareStaging('../x', 1), throwsArgumentError);
      expect(() => store.discardStaging('../x', 1), throwsArgumentError);
      expect(() => store.discardStagedFile('..', 1, 'a'), throwsArgumentError);
    });
  });

  group('activate', () {
    test('moves staging into packs and names it active', () async {
      final stored = await install(1);
      expect(stored, (
        id: _id,
        active: 1,
        previous: null,
        directory: at('packs/$_id/1'),
      ));
      expect(await read('packs/$_id/1/data.bin'), 'synthetic 1');
      expect(exists('pack-staging/$_id/1'), isFalse);
      expect(await activeJson(), {'active': 1, 'previous': null});
      expect(exists('packs/$_id/active.json.tmp'), isFalse);
    });

    test(
      'keeps the version before as previous and removes older ones',
      () async {
        await install(1);
        expect((await install(2)).previous, 1);
        expect(await activeJson(), {'active': 2, 'previous': 1});
        final third = await install(3);
        expect((third.active, third.previous), (3, 2));
        expect(exists('packs/$_id/1'), isFalse);
        expect(await read('packs/$_id/2/data.bin'), 'synthetic 2');
      },
    );

    test('never replaces a version in packs', () async {
      await install(1);
      await store.prepareStaging(_id, 1);
      expect(
        await store.activate(_id, 1),
        isA<Failure<StoredPack>>().having(
          (f) => f.error,
          'error',
          isA<AlreadyInstalled>().having((e) => e.version, 'version', 1),
        ),
      );
      expect(await read('packs/$_id/1/data.bin'), 'synthetic 1');
    });

    test(
      'never moves a version into a folder that is not the store\'s',
      () async {
        await write('packs/$_id/1/data.bin', 'synthetic foreign');
        await store.prepareStaging(_id, 2);
        expect(
          await store.activate(_id, 2),
          isA<Failure<StoredPack>>().having(
            (f) => f.error,
            'error',
            isA<StoreFailed>(),
          ),
        );
        expect(await read('packs/$_id/1/data.bin'), 'synthetic foreign');
        expect(exists('packs/$_id/2'), isFalse);
      },
    );

    test('takes a folder that holds only a temporary file left by a cut-short '
        'activation', () async {
      await write('packs/$_id/active.json.tmp', '{"active":1,"previous":null}');
      expect((await install(1)).active, 1);
      expect(await activeJson(), {'active': 1, 'previous': null});
    });

    test('refuses a version with nothing staged, and an invalid id', () async {
      expect(
        await store.activate(_id, 1),
        isA<Failure<StoredPack>>().having(
          (f) => f.error,
          'error',
          isA<StoreFailed>(),
        ),
      );
      expect(
        await store.activate('../x', 1),
        isA<Failure<StoredPack>>().having(
          (f) => f.error,
          'error',
          isA<InvalidPackId>(),
        ),
      );
    });
  });

  group('rollback', () {
    test('swaps active and previous, and can be undone', () async {
      await install(1);
      await install(2);
      final back = await store.rollback(_id);
      expect(back, isA<Ok<StoredPack>>());
      expect((back as Ok<StoredPack>).value, (
        id: _id,
        active: 1,
        previous: 2,
        directory: at('packs/$_id/1'),
      ));
      expect(await activeJson(), {'active': 1, 'previous': 2});
      expect(await store.rollback(_id), isA<Ok<StoredPack>>());
      expect(await activeJson(), {'active': 2, 'previous': 1});
    });

    test('without a previous version on disk there is none', () async {
      Future<void> expectNone(String id) async => expect(
        await store.rollback(id),
        isA<Failure<StoredPack>>().having(
          (f) => f.error,
          'error',
          isA<NoPreviousVersion>(),
        ),
      );
      await expectNone(_id);
      await install(1);
      await expectNone(_id);
      await install(2);
      await Directory(at('packs/$_id/1')).delete(recursive: true);
      await expectNone(_id);
      expect(
        await store.rollback('A'),
        isA<Failure<StoredPack>>().having(
          (f) => f.error,
          'error',
          isA<InvalidPackId>(),
        ),
      );
    });
  });

  test('readAll lists the packs with an active.json, by id', () async {
    expect(await store.readAll(), isEmpty);
    await install(1, id: 'synthetic-b');
    await install(1);
    await install(2);
    await write('packs/synthetic-foreign/1/data.bin', 'synthetic');
    await write('packs/Not-An-Id/active.json', '{"active":1,"previous":null}');
    await write('packs/stray.txt', 'synthetic');
    expect(await store.readAll(), [
      (
        id: 'synthetic-b',
        active: 1,
        previous: null,
        directory: at('packs/synthetic-b/1'),
      ),
      (id: _id, active: 2, previous: 1, directory: at('packs/$_id/2')),
    ]);
  });

  group('delete', () {
    test('removes the pack and its staging, nothing else', () async {
      await install(1);
      await install(2);
      await install(1, id: 'synthetic-other');
      await store.prepareStaging(_id, 3);
      await store.prepareStaging('synthetic-other', 2);
      await write('user.sqlite', 'synthetic user data');
      await write('packs/synthetic-foreign/1/data.bin', 'synthetic');

      expect(await store.delete(_id), isA<Ok<void>>());

      expect(exists('packs/$_id'), isFalse);
      expect(exists('pack-staging/$_id'), isFalse);
      expect(await Directory(at('pack-staging/.removed')).list().isEmpty, true);
      expect(await read('user.sqlite'), 'synthetic user data');
      expect(await read('packs/synthetic-other/1/data.bin'), 'synthetic 1');
      expect(exists('pack-staging/synthetic-other/2'), isTrue);
      expect(await read('packs/synthetic-foreign/1/data.bin'), 'synthetic');
      expect(
        [for (final pack in await store.readAll()) pack.id],
        ['synthetic-other'],
      );
    });

    test(
      'leaves a folder without active.json, and refuses an invalid id',
      () async {
        await write('packs/synthetic-foreign/1/data.bin', 'synthetic');
        await write('pack-staging/synthetic-foreign/1/data.bin', 'synthetic');
        expect(await store.delete('synthetic-foreign'), isA<Ok<void>>());
        expect(exists('packs/synthetic-foreign/1/data.bin'), isTrue);
        expect(exists('pack-staging/synthetic-foreign/1/data.bin'), isTrue);
        expect(
          await store.delete('..'),
          isA<Failure<void>>().having(
            (f) => f.error,
            'error',
            isA<InvalidPackId>(),
          ),
        );
      },
    );
  });

  group('recover', () {
    test('finishes an activation cut short after the move', () async {
      await install(1);
      await write('packs/$_id/2/data.bin', 'synthetic 2');
      await write('packs/$_id/active.json.tmp', '{"active":2,"previous":1}');
      await store.recover();
      expect(await activeJson(), {'active': 2, 'previous': 1});
      expect(exists('packs/$_id/active.json.tmp'), isFalse);
    });

    test('drops a temporary file that names a missing version', () async {
      await install(1);
      await write('packs/$_id/active.json.tmp', '{"active":2,"previous":1}');
      await store.recover();
      expect(await activeJson(), {'active': 1, 'previous': null});
      expect(exists('packs/$_id/active.json.tmp'), isFalse);

      await write('packs/synthetic-new/active.json.tmp', 'not json');
      await store.recover();
      expect(exists('packs/synthetic-new/active.json.tmp'), isFalse);
    });

    test(
      'falls back to the previous version when the active one is missing',
      () async {
        await install(1);
        await install(2);
        await Directory(at('packs/$_id/2')).delete(recursive: true);
        await store.recover();
        expect(await activeJson(), {'active': 1, 'previous': null});
      },
    );

    test('drops a missing previous version', () async {
      await install(1);
      await install(2);
      await Directory(at('packs/$_id/1')).delete(recursive: true);
      await store.recover();
      expect(await activeJson(), {'active': 2, 'previous': null});
    });

    test(
      'drops active.json when no version is left, or it is unreadable',
      () async {
        await install(1);
        await Directory(at('packs/$_id/1')).delete(recursive: true);
        await install(1, id: 'synthetic-b');
        await write('packs/synthetic-b/active.json', '{"active":0}');
        await store.recover();
        expect(exists('packs/$_id'), isFalse);
        expect(exists('packs/synthetic-b'), isFalse);
        expect(
          await Directory(at('pack-staging/.removed')).list().isEmpty,
          true,
        );
        expect(await store.readAll(), isEmpty);
      },
    );

    test('removes stray versions and staging at or below the active one, '
        'and keeps newer staging', () async {
      await install(1);
      await install(2);
      await write('packs/$_id/7/data.bin', 'synthetic stray');
      await write('packs/$_id/notes/data.bin', 'synthetic');
      await write('pack-staging/$_id/1/data.bin', 'synthetic');
      await write('pack-staging/$_id/2/data.bin', 'synthetic');
      await write('pack-staging/$_id/3/data.bin', 'synthetic');
      await write('pack-staging/synthetic-first/1/data.bin', 'synthetic');
      await write('packs/synthetic-foreign/9/data.bin', 'synthetic');
      await store.recover();
      expect(exists('packs/$_id/7'), isFalse);
      expect(exists('packs/$_id/notes/data.bin'), isTrue);
      expect(exists('packs/$_id/1'), isTrue);
      expect(exists('packs/$_id/2'), isTrue);
      expect(exists('pack-staging/$_id/1'), isFalse);
      expect(exists('pack-staging/$_id/2'), isFalse);
      expect(exists('pack-staging/$_id/3/data.bin'), isTrue);
      expect(exists('pack-staging/synthetic-first/1/data.bin'), isTrue);
      expect(exists('packs/synthetic-foreign/9/data.bin'), isTrue);
    });

    test('finishes a removal cut short', () async {
      await write('pack-staging/.removed/$_id-1/1/data.bin', 'synthetic');
      await store.recover();
      expect(exists('pack-staging/.removed'), isFalse);
    });

    test('with no packs folder does nothing', () async {
      await store.recover();
      expect(exists('packs'), isFalse);
    });
  });
}
