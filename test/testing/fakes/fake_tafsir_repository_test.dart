import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/data/repositories/tafsir_repository.dart';
import 'package:holyquran/domain/models/installed_pack.dart';
import 'package:holyquran/domain/models/pack_manifest.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/tafsir_book.dart';
import 'package:holyquran/domain/models/tafsir_position.dart';
import 'package:holyquran/utils/result.dart';

import '../../../testing/fakes/fake_tafsir_repository.dart';

final _pack = InstalledPack(
  manifest: PackManifest(
    formatVersion: 2,
    id: 'synthetic-tafsir',
    kind: PackKind.tafsir,
    version: 1,
    changelog: const [],
    riwaya: 'hafs',
    sources: const [],
    files: const [],
    counts: const TafsirCounts(passages: 0),
    reviews: const [],
  ),
  directory: '/synthetic/packs/synthetic-tafsir/1',
  previousVersion: null,
);

const _book = TafsirBook(
  title: PackText.fromPack('Synthetic title'),
  author: PackText.fromPack('Synthetic author'),
  publisher: null,
  edition: null,
  editor: null,
);

final _ayah = QuranAddress('hafs', 1, 1);

final Matcher _notInstalled = isA<Failure<Object?>>().having(
  (f) => f.error,
  'error',
  isA<TafsirNotInstalled>(),
);

void main() {
  test('starts with what it is given', () async {
    final repository = FakeTafsirRepository(
      installed: [_pack],
      defaultTafsir: 'synthetic-tafsir',
      books: {'synthetic-tafsir': _book},
    );
    addTearDown(repository.dispose);

    expect(repository.installed, [_pack]);
    expect(repository.defaultTafsir, 'synthetic-tafsir');
    expect(
      await repository.book('synthetic-tafsir'),
      isA<Ok<TafsirBook>>().having((r) => r.value, 'value', same(_book)),
    );
    expect(
      () => repository.positionAt('synthetic-tafsir', _ayah),
      throwsStateError,
    );
  });

  test(
    'a pack that is not installed has no book, position or default',
    () async {
      final repository =
          FakeTafsirRepository(
              defaultTafsir: 'synthetic-tafsir',
              books: {'synthetic-tafsir': _book},
            )
            ..positions = (_, ayah) => Ok(
              TafsirPosition(
                ayah: ayah,
                passage: null,
                previous: null,
                next: null,
              ),
            );
      addTearDown(repository.dispose);

      expect(repository.defaultTafsir, isNull);
      expect(await repository.book('synthetic-tafsir'), _notInstalled);
      expect(
        await repository.positionAt('synthetic-tafsir', _ayah),
        _notInstalled,
      );
      expect(
        await repository.setDefaultTafsir('synthetic-tafsir'),
        _notInstalled,
      );
    },
  );

  test('setting installed packs and the default notifies', () async {
    final repository = FakeTafsirRepository();
    addTearDown(repository.dispose);
    var notified = 0;
    repository.addListener(() => notified++);

    repository.installed = [_pack];
    expect(
      await repository.setDefaultTafsir('synthetic-tafsir'),
      isA<Ok<void>>(),
    );
    expect(repository.defaultTafsir, 'synthetic-tafsir');
    expect(notified, 2);
  });

  test('answers positions as the test sets them', () async {
    final repository = FakeTafsirRepository(installed: [_pack])
      ..positions = (_, ayah) => Ok(
        TafsirPosition(ayah: ayah, passage: null, previous: null, next: null),
      );
    addTearDown(repository.dispose);

    expect(
      await repository.positionAt('synthetic-tafsir', _ayah),
      isA<Ok<TafsirPosition>>().having((r) => r.value.ayah, 'ayah', _ayah),
    );
  });
}
