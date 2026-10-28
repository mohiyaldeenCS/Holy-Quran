import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/data/repositories/catalogue_repository.dart';
import 'package:holyquran/domain/models/pack_failure.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/features/tafsir/tafsir_copy_text.dart';
import 'package:holyquran/ui/features/tafsir/view_models/tafsir_view_model.dart';
import 'package:holyquran/utils/result.dart';

import '../../../../testing/fakes/fake_catalogue_repository.dart';
import '../../../../testing/packs/synthetic_tafsir_pack.dart';
import '../resources/resources_fixtures.dart';
import 'tafsir_fixture.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

void main() {
  late TafsirFixture fixture;
  final copied = <String>[];

  setUp(() async {
    copied.clear();
    fixture = await TafsirFixture.open();
  });

  tearDown(() => fixture.close());

  QuranAddress at(int surah, int ayah) =>
      QuranAddress(fixture.quran.riwaya, surah, ayah);

  Future<TafsirViewModel> open(
    QuranAddress address, {
    CatalogueRepository? catalogue,
    bool withTafsirs = true,
  }) async {
    final model = TafsirViewModel(
      address: address,
      quran: fixture.quran,
      tafsirs: withTafsirs ? fixture.tafsirs : null,
      catalogue: catalogue,
      copyText: withTafsirs
          ? TafsirCopyText(
              tafsirs: fixture.tafsirs,
              quran: fixture.quran,
              l10n: _l10n,
            )
          : null,
      copyToClipboard: (text) async {
        copied.add(text);
        return const Ok(null);
      },
    );
    addTearDown(model.dispose);
    await _until(() => model.loaded);
    return model;
  }

  test('reads the ayah, its surah and its passage from the packs', () async {
    final model = await open(at(1, 2));

    expect(model.address, at(1, 2));
    final stored = await fixture.quran.ayahText(at(1, 2));
    expect(model.ayahText, (stored as Ok<PackText>).value);
    final page = model.page!;
    expect(page.packId, TafsirFixture.bookId);
    expect(page.version, 1);
    expect(page.source, 'Synthetic tafsir source');
    expect(
      utf8.encode(page.passage!.text.verbatim),
      utf8.encode(defaultSyntheticPassages[0].text),
    );
    expect(model.failure, isNull);
  });

  test('a passage over several ayat is one range, shown once', () async {
    final model = await open(at(1, 2));

    expect(model.page!.range, (first: 1, last: 3));
    // From the middle of the range the steps still leave it whole.
    expect(model.previous, isNull);
    expect(model.next, at(1, 4));

    await model.goTo(at(2, 3));
    expect(model.page!.range, (first: 2, last: 3));
    expect(model.previous, at(2, 1));
    expect(model.next, at(3, 1));
  });

  test('a passage over one ayah has no range', () async {
    final model = await open(at(2, 1));

    expect(model.page!.range, isNull);
  });

  test('steps ayah by ayah across a surah, with the ayah and the surah '
      'following', () async {
    final model = await open(at(1, 1));
    final seen = <QuranAddress>[];

    for (var next = model.next; next != null; next = model.next) {
      seen.add(model.address);
      await model.goTo(next);
    }
    seen.add(model.address);

    // 1:1-3 is one passage, 1:4 has none, then 2:1, 2:2-3 and 3:1.
    expect(seen, [at(1, 1), at(1, 4), at(2, 1), at(2, 2), at(3, 1)]);
    expect(model.next, isNull);
    expect(model.surahName, isNotNull);
    expect(model.address.surah, 3);

    final back = <QuranAddress>[];
    for (
      var previous = model.previous;
      previous != null;
      previous = model.previous
    ) {
      back.add(model.address);
      await model.goTo(previous);
    }
    expect(back, [at(3, 1), at(2, 2), at(2, 1), at(1, 4)]);
    expect(model.address, at(1, 1));
  });

  test(
    'the last of several steps asked for at once is the one shown',
    () async {
      final model = await open(at(1, 1));

      final first = model.goTo(at(2, 1));
      final last = model.goTo(at(3, 1));
      await Future.wait([first, last]);
      await _until(() => model.address == at(3, 1));
      // Let a late answer for 2:1 arrive before judging.
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(model.address, at(3, 1));
      expect(model.page!.position.ayah, at(3, 1));
    },
  );

  test('an ayah the book has no passage for has a page without one', () async {
    final model = await open(at(1, 4));

    expect(model.page, isNotNull);
    expect(model.page!.passage, isNull);
    expect(model.page!.range, isNull);
    expect(model.previous, at(1, 1));
    expect(model.next, at(2, 1));
  });

  test('with no tafsir downloaded it has no page and no failure', () async {
    await fixture.close();
    fixture = await TafsirFixture.open(install: false);

    final model = await open(at(1, 1));

    expect(model.hasTafsirs, isFalse);
    expect(model.page, isNull);
    expect(model.failure, isNull);
    expect(model.ayahText, isNotNull);
    expect(model.downloaded, isEmpty);
  });

  test('with no tafsir repository it reads the ayah alone', () async {
    final model = await open(at(1, 1), withTafsirs: false);

    expect(model.hasTafsirs, isFalse);
    expect(model.page, isNull);
    expect(model.canCopy, isFalse);
    expect(model.ayahText, isNotNull);
  });

  test('shows the first book downloaded while none is the default, then '
      'the one chosen', () async {
    await fixture.install(
      id: 'synthetic-tafsir-b',
      book: const SyntheticBook(title: 'Synthetic second title', author: 'B'),
    );
    final model = await open(at(1, 1));

    expect(model.page!.packId, TafsirFixture.bookId);
    expect(model.downloaded.map((choice) => choice.packId), [
      TafsirFixture.bookId,
      'synthetic-tafsir-b',
    ]);
    expect(model.downloaded.map((choice) => choice.chosen), [true, false]);

    await model.choose('synthetic-tafsir-b');
    await _until(() => model.page?.packId == 'synthetic-tafsir-b');

    expect(fixture.tafsirs.defaultTafsir, 'synthetic-tafsir-b');
    expect(model.page!.packId, 'synthetic-tafsir-b');
    expect(model.downloaded.map((choice) => choice.chosen), [false, true]);
  });

  test('lists the tafsirs the catalogue offers that are not downloaded, '
      'apart from the downloaded', () async {
    final catalogue = FakeCatalogueRepository(catalogueWith());
    addTearDown(catalogue.dispose);
    final model = await open(at(1, 1), catalogue: catalogue);

    // Not the downloaded 'synthetic-tafsir', and no recitation or text pack.
    expect(model.available, [for (final id in extraTafsirs) titleOf(id)]);
    expect(model.downloaded, hasLength(1));
  });

  test('a book that fails its checks is a failure, not a page', () async {
    await fixture.close();
    fixture = await TafsirFixture.open(install: false);
    await fixture.install(corrupt: true);

    final model = await open(at(1, 1));

    expect(model.page, isNull);
    expect(model.failure, isA<PackFailure>());
  });

  test('copies the passage with its attribution to the clipboard', () async {
    final model = await open(at(1, 2));

    expect(model.canCopy, isTrue);
    await model.copy.execute();

    expect(model.copy.completed, isTrue);
    expect(copied, hasLength(1));
    expect(copied.single, contains(defaultSyntheticPassages[0].text));
    expect(copied.single, contains(defaultSyntheticBook.title));
  });

  test('copies nothing for an ayah without a passage', () async {
    final model = await open(at(1, 4));

    await model.copy.execute();

    expect(model.copy.error, isTrue);
    expect(copied, isEmpty);
  });

  test('reads again when a book is downloaded or removed', () async {
    await fixture.close();
    fixture = await TafsirFixture.open(install: false);
    final model = await open(at(1, 1));
    expect(model.page, isNull);

    await fixture.install();
    await _until(() => model.page != null);

    expect(model.hasTafsirs, isTrue);

    fixture.installs.installed = [];
    await _until(() => model.page == null);

    expect(model.hasTafsirs, isFalse);
    expect(model.page, isNull);
  });
}

/// Waits, in real time, for [condition], which the model's reads bring about.
Future<void> _until(bool Function() condition) async {
  for (var i = 0; i < 500 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(condition(), isTrue, reason: 'the model did not settle');
}
