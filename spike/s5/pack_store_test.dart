import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/utils/result.dart';

import 'pack_store.dart';

void main() {
  late Directory root;
  late PackStore store;
  const id = 'synthetic-text';

  setUp(() async {
    root = await Directory.systemTemp.createTemp('s5_store');
    store = PackStore(root);
  });

  tearDown(() => root.delete(recursive: true));

  /// Stages [version] with one file holding [marker], then activates it.
  Future<Result<PackVersions>> install(int version, {String? marker}) async {
    final staging = await store.stagingFor(id, version);
    await File('${staging.path}/data').writeAsString(marker ?? 'v$version');
    return store.activate(id, version);
  }

  Future<String> currentFile() =>
      File('${root.path}/packs/$id/current').readAsString();

  Future<List<String>> versionDirs() async => [
    for (final e in Directory('${root.path}/packs/$id').listSync())
      if (e is Directory) e.uri.pathSegments.lastWhere((s) => s.isNotEmpty),
  ]..sort();

  test(
    'stagingFor gives an empty directory under staging/<id>/<version>',
    () async {
      final first = await store.stagingFor(id, 1);
      expect(first.path, '${root.path}/staging/$id/1');
      await File('${first.path}/left-over').writeAsString('synthetic');
      final again = await store.stagingFor(id, 1);
      expect(again.listSync(), isEmpty);
    },
  );

  test('activate moves staging into packs and names it current', () async {
    expect(await store.currentVersion(id), isNull);
    final result = await install(1);
    expect(result, isA<Ok<PackVersions>>());
    expect((result as Ok<PackVersions>).value, (active: 1, previous: null));
    expect(await store.currentVersion(id), 1);
    expect(await currentFile(), '1\n');
    expect(store.directoryOf(id, 1).path, '${root.path}/packs/$id/1');
    expect(
      await File('${store.directoryOf(id, 1).path}/data').readAsString(),
      'v1',
    );
    expect(await Directory('${root.path}/staging/$id/1').exists(), isFalse);
    expect(await File('${root.path}/packs/$id/current.tmp').exists(), isFalse);
  });

  test('activate without staging fails', () async {
    final result = await store.activate(id, 1);
    expect(result, isA<Failure<PackVersions>>());
    expect((result as Failure<PackVersions>).error, isA<StagingMissing>());
  });

  test('activate refuses to overwrite an installed version', () async {
    await install(1, marker: 'first');
    final result = await install(1, marker: 'second');
    expect((result as Failure<PackVersions>).error, isA<VersionExists>());
    expect(
      await File('${store.directoryOf(id, 1).path}/data').readAsString(),
      'first',
    );
    expect(await store.currentVersion(id), 1);
    expect(await store.hasVersion(id, 1), isTrue);
  });

  test(
    'keeps the active and one previous version and deletes older ones',
    () async {
      await install(1);
      await install(2);
      expect(await currentFile(), '2\n1\n');
      expect(await versionDirs(), ['1', '2']);
      await install(3);
      expect(await store.versionsOf(id), (active: 3, previous: 2));
      expect(await versionDirs(), ['2', '3']);
    },
  );

  test(
    'rollback makes the previous version current and can be undone',
    () async {
      await install(1);
      await install(2);
      final back = await store.rollback(id);
      expect((back as Ok<PackVersions>).value, (active: 1, previous: 2));
      expect(await store.currentVersion(id), 1);
      expect(await versionDirs(), ['1', '2']);
      await store.rollback(id);
      expect(await store.currentVersion(id), 2);
    },
  );

  test(
    'a version installed after a rollback replaces the rolled-back one',
    () async {
      await install(1);
      await install(2);
      await store.rollback(id);
      await install(3);
      expect(await store.versionsOf(id), (active: 3, previous: 1));
      expect(await versionDirs(), ['1', '3']);
    },
  );

  test(
    'rollback without a previous version fails and changes nothing',
    () async {
      expect(
        (await store.rollback(id) as Failure<PackVersions>).error,
        isA<NoPreviousVersion>(),
      );
      await install(1);
      expect(
        (await store.rollback(id) as Failure<PackVersions>).error,
        isA<NoPreviousVersion>(),
      );
      expect(await store.currentVersion(id), 1);
    },
  );

  test('discardStaging deletes a staging directory', () async {
    await store.stagingFor(id, 4);
    await store.discardStaging(id, 4);
    expect(await Directory('${root.path}/staging/$id/4').exists(), isFalse);
    await store.discardStaging(id, 4);
  });

  group('recover', () {
    test('does nothing on an empty root', () async {
      expect(await store.recover(), isEmpty);
    });

    test(
      'deletes leftover staging and current.tmp and keeps current',
      () async {
        await install(1);
        final staging = await store.stagingFor(id, 2);
        await File('${staging.path}/partial').writeAsString('synthetic');
        await File(
          '${root.path}/packs/$id/current.tmp',
        ).writeAsString('2\n1\n');
        final actions = await store.recover();
        expect(actions, [
          'deleted staging (1 files)',
          '$id: deleted current.tmp',
        ]);
        expect(await Directory('${root.path}/staging').exists(), isFalse);
        expect(
          await File('${root.path}/packs/$id/current.tmp').exists(),
          isFalse,
        );
        expect(await store.versionsOf(id), (active: 1, previous: null));
      },
    );

    test('falls back to the previous version when current names a missing '
        'directory', () async {
      await install(1);
      await install(2);
      await store.directoryOf(id, 2).delete(recursive: true);
      final actions = await store.recover();
      expect(actions, ['$id: 2 missing, back to 1']);
      expect(await store.versionsOf(id), (active: 1, previous: null));
    });

    test('removes current when no named version is left', () async {
      await install(1);
      await store.directoryOf(id, 1).delete(recursive: true);
      expect(await store.recover(), ['$id: no installed version left']);
      expect(await store.currentVersion(id), isNull);
    });

    test('deletes an unreadable current', () async {
      await install(1);
      await File('${root.path}/packs/$id/current').writeAsString('one\n');
      expect(await store.recover(), ['$id: deleted unreadable current']);
      expect(await store.currentVersion(id), isNull);
    });

    test('deletes a version moved in but never made current', () async {
      await install(1);
      await Directory('${root.path}/packs/$id/2').create();
      expect(await store.recover(), ['$id: deleted 2']);
      expect(await versionDirs(), ['1']);
    });
  });
}
