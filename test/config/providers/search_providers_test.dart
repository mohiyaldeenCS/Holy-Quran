import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/config/dependencies.dart';
import 'package:holyquran/config/providers/search_providers.dart';
import 'package:holyquran/data/models/pack_manifest_json.dart';
import 'package:holyquran/data/repositories/search_repository.dart';
import 'package:holyquran/data/repositories/tafsir_search_repository.dart';
import 'package:holyquran/domain/models/pack_failure.dart';
import 'package:holyquran/domain/models/pack_manifest.dart';
import 'package:holyquran/domain/models/quran_structure.dart';
import 'package:holyquran/domain/models/search_hit.dart';
import 'package:holyquran/domain/models/verified_pack.dart';
import 'package:holyquran/utils/result.dart';

import '../../../testing/fakes/fake_quran_index_repository.dart';
import '../../../testing/packs/synthetic_pack.dart';
import '../../../testing/packs/synthetic_tafsir_pack.dart';

VerifiedPack _verified(Directory directory, String id) => VerifiedPack(
  directory: directory.path,
  manifest:
      (parsePackManifest(
                File('${directory.path}/$manifestFileName').readAsBytesSync(),
                pack: id,
              )
              as Ok<PackManifest>)
          .value,
  signatureChecked: false,
);

void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('search_providers'));
  tearDown(() => root.deleteSync(recursive: true));

  /// The [T] provided after the structure area and [area].
  Future<T> provided<T extends Object>(AreaSetup area) async {
    late T value;
    await buildDependencies(
      areas: [
        (d) async =>
            d.provide<QuranStructure>(FakeQuranIndexRepository.synthetic()),
        area,
        (d) async => value = d.read<T>(),
      ],
    );
    return value;
  }

  test('the search area alone provides nothing', () async {
    expect(await buildDependencies(areas: [searchProviders]), isEmpty);
  });

  test('provides the search of the base pack', () async {
    final pack = await buildSyntheticPack(root, formatVersion: 2);
    var serving = true;
    final failures = <Exception>[];
    final repository = await provided<SearchRepository>(
      (d) async => provideSearch(
        d,
        pack: _verified(pack.directory, 'synthetic-text'),
        serving: () => serving,
        failed: failures.add,
      ),
    );
    expect(
      (await repository.formKinds() as Ok<List<String>>).value,
      defaultSyntheticSearchFormKinds,
    );
    serving = false;
    expect(
      await repository.formKinds(),
      isA<Failure<List<String>>>().having(
        (f) => f.error,
        'error',
        isA<PackDisabled>(),
      ),
    );
    expect(failures, isEmpty);
  });

  test('passes a failed index build on', () async {
    final pack = await buildSyntheticPack(
      root,
      formatVersion: 2,
      searchFormFault: SyntheticSearchFormFault.missing,
    );
    final failures = <Exception>[];
    final repository = await provided<SearchRepository>(
      (d) async => provideSearch(
        d,
        pack: _verified(pack.directory, 'synthetic-text'),
        serving: () => true,
        failed: failures.add,
      ),
    );
    expect(await repository.formKinds(), isA<Failure<List<String>>>());
    expect(failures.single, isA<PackInconsistent>());
  });

  test('provides the search of installed tafsir books', () async {
    final book = await buildSyntheticTafsirPack(root);
    final repository = await provided<TafsirSearchRepository>(
      (d) async => provideTafsirSearch(
        d,
        installed: () async => [_verified(book.directory, 'synthetic-tafsir')],
        failed: (_) {},
      ),
    );
    final hits =
        (await repository.search('Synthetic', ['synthetic-tafsir'])
                as Ok<List<TafsirHit>>)
            .value;
    expect([for (final hit in hits) hit.passage.number], [3, 4]);
  });
}
