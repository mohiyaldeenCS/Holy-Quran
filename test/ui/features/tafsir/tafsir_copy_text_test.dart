import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/data/repositories/tafsir_repository.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/features/tafsir/tafsir_copy_text.dart';
import 'package:holyquran/utils/result.dart';

import '../../../../testing/packs/synthetic_tafsir_pack.dart';
import 'tafsir_fixture.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

/// The ARB template, read from the file so the test types no wording.
final _format =
    (jsonDecode(File('lib/l10n/app_ar.arb').readAsStringSync())
            as Map<String, Object?>)['tafsirCopyFormat']!
        as String;

String _expected({
  required String passage,
  required String ayahs,
  required String surah,
}) => _format
    .replaceAll('{passage}', passage)
    .replaceAll('{title}', defaultSyntheticBook.title)
    .replaceAll('{author}', defaultSyntheticBook.author)
    .replaceAll('{surah}', surah)
    .replaceAll('{ayahs}', ayahs)
    .replaceAll('{source}', 'Synthetic tafsir source')
    .replaceAll('{version}', _l10n.sourceVersion(arabicDigits(1)));

void main() {
  late TafsirFixture fixture;
  late TafsirCopyText copyText;

  setUp(() async {
    fixture = await TafsirFixture.open();
    copyText = TafsirCopyText(
      tafsirs: fixture.tafsirs,
      quran: fixture.quran,
      l10n: _l10n,
    );
  });

  tearDown(() => fixture.close());

  QuranAddress at(int surah, int ayah) =>
      QuranAddress(fixture.quran.riwaya, surah, ayah);

  Future<String> surahName(int surah) async =>
      switch (await fixture.quran.surahs()) {
        Ok(:final value) =>
          value.singleWhere((s) => s.number == surah).name.verbatim,
        Failure(:final error) => throw TestFailure('$error'),
      };

  test('copies a passage whole with the book, the reference and the '
      'source', () async {
    // The default passage over 2:2 to 2:3; its text would change under any
    // trimming or normalising.
    final passage = defaultSyntheticPassages[2];
    final copied = switch (await copyText.compose(
      TafsirFixture.bookId,
      at(2, 3),
    )) {
      Ok(:final value) => value,
      Failure(:final error) => throw TestFailure('$error'),
    };

    expect(
      utf8.encode(copied),
      utf8.encode(
        _expected(
          passage: passage.text,
          ayahs: _l10n.ayahsRangeShort(arabicDigits(2), arabicDigits(3)),
          surah: await surahName(2),
        ),
      ),
    );
  });

  test('writes one ayah number for a passage over one ayah', () async {
    final passage = defaultSyntheticPassages[1];
    final copied = switch (await copyText.compose(
      TafsirFixture.bookId,
      at(2, 1),
    )) {
      Ok(:final value) => value,
      Failure(:final error) => throw TestFailure('$error'),
    };

    expect(copied, contains(passage.text));
    expect(
      copied,
      _expected(
        passage: passage.text,
        ayahs: arabicDigits(1),
        surah: await surahName(2),
      ),
    );
  });

  test('copies the passage over the ayah asked for, from any ayah of its '
      'range', () async {
    final first = await copyText.compose(TafsirFixture.bookId, at(1, 1));
    final last = await copyText.compose(TafsirFixture.bookId, at(1, 3));

    expect(first, isA<Ok<String>>());
    expect((first as Ok<String>).value, (last as Ok<String>).value);
  });

  test('has nothing to copy for an ayah without a passage', () async {
    final result = await copyText.compose(TafsirFixture.bookId, at(1, 4));

    expect(
      result,
      isA<Failure<String>>().having(
        (f) => f.error,
        'error',
        isA<NoPassageToCopy>().having((e) => e.ayah, 'ayah', at(1, 4)),
      ),
    );
  });

  test('fails for a book that is not installed', () async {
    final result = await copyText.compose('synthetic-other', at(1, 1));

    expect(
      result,
      isA<Failure<String>>().having(
        (f) => f.error,
        'error',
        isA<TafsirNotInstalled>(),
      ),
    );
  });
}
