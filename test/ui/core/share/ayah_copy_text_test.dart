import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/data/repositories/pack_quran_text_repository.dart';
import 'package:holyquran/domain/models/copy_form.dart';
import 'package:holyquran/domain/models/pack_failure.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/share/ayah_copy_text.dart';
import 'package:holyquran/utils/result.dart';

import '../../../integrity/pack_integrity_suite.dart';
import 'share_test_pack.dart';

// SH-01 and SH-05: the copied text is the pack's bytes in the ARB format,
// for every ayah of the synthetic pack and of a pack given with
// HOLYQURAN_PACK_DIR. The format is read from the ARB file, so no template
// is typed here; nothing of the text is ever printed.

final _l10n = lookupAppLocalizations(const Locale('ar'));

final _templates =
    jsonDecode(File('lib/l10n/app_ar.arb').readAsStringSync())
        as Map<String, Object?>;

final _placeholder = RegExp(r'\{(\w+)\}');

/// The bytes of `copyFormatFull` filled with the stored [ayah] and [surah]
/// and the number [ayahNumber] in Arabic-Indic digits.
List<int> _expected(List<int> ayah, List<int> surah, int ayahNumber) {
  final template = _templates['copyFormatFull']! as String;
  final bytes = <int>[];
  var at = 0;
  for (final match in _placeholder.allMatches(template)) {
    bytes
      ..addAll(utf8.encode(template.substring(at, match.start)))
      ..addAll(switch (match[1]) {
        'ayah' => ayah,
        'surah' => surah,
        'number' => utf8.encode(arabicDigits(ayahNumber)),
        final other => fail('copyFormatFull has the placeholder $other'),
      });
    at = match.end;
  }
  return bytes..addAll(utf8.encode(template.substring(at)));
}

void _copiesEveryAyah(String description, Future<String> Function() directory) {
  test('$description: every ayah is copied as its stored bytes in the full '
      'form', () async {
    final pack = await PackUnderTest.load(await directory());
    addTearDown(pack.close);
    final repository = pack.openRepository();
    final copyText = AyahCopyText(repository, _l10n);
    final ayat = await packAyat(pack, repository);
    expect(ayat, hasLength(pack.manifest.counts.ayat));
    final problems = <String>[];
    for (final ayah in ayat) {
      switch (await copyText.compose(
        ayah.address,
        CopyForm.withSurahAndNumber,
      )) {
        case Ok(:final value):
          final mismatch = byteMismatch(
            utf8.encode(value),
            _expected(ayah.stored, ayah.storedName, ayah.address.ayah),
          );
          if (mismatch != null) problems.add('${ayah.address}: $mismatch');
        case Failure(:final error):
          problems.add('${ayah.address}: $error');
      }
    }
    expectNoProblems(problems);
  });
}

void main() {
  _copiesEveryAyah('the synthetic pack', () async {
    final pack = await loadShareTestPack();
    return pack.directory;
  });

  if (givenPackDirectory.isEmpty) {
    test(
      'the pack given with HOLYQURAN_PACK_DIR',
      () {},
      skip: 'no --dart-define=HOLYQURAN_PACK_DIR=<pack-id/version> was given',
    );
  } else {
    _copiesEveryAyah(
      'the pack HOLYQURAN_PACK_DIR=$givenPackDirectory',
      () async => givenPackDirectory,
    );
  }

  group('with the synthetic pack', () {
    late PackUnderTest pack;
    late PackQuranTextRepository repository;
    late AyahCopyText copyText;

    setUpAll(() async {
      pack = await loadShareTestPack();
    });
    setUp(() {
      repository = pack.openRepository();
      copyText = AyahCopyText(repository, _l10n);
    });

    test('offers only the forms whose format the ARB file gives', () {
      expect(copyText.forms, [CopyForm.withSurahAndNumber]);
    });

    test('refuses a form with no format', () async {
      final address = QuranAddress(repository.riwaya, 1, 1);
      for (final form in [CopyForm.ayahOnly, CopyForm.withSurah]) {
        expect(
          await copyText.compose(address, form),
          isA<Failure<String>>().having(
            (failure) => failure.error,
            'error',
            isA<CopyFormUnavailable>().having((e) => e.form, 'form', form),
          ),
        );
      }
    });

    test('previews every ayah as the pack holds it, and the preview laid out '
        'is the copied text', () async {
      final problems = <String>[];
      for (final ayah in await packAyat(pack, repository)) {
        for (final form in copyText.forms) {
          final preview = await copyText.preview(ayah.address, form);
          final copied = await copyText.compose(ayah.address, form);
          if ((preview, copied) case (
            Ok(value: (ayah: final previewed, :final reference)),
            Ok(value: final text),
          )) {
            final shown =
                '${_l10n.ayahQuoteOpen}${previewed.verbatim}'
                '${_l10n.ayahQuoteClose} $reference';
            final mismatch = byteMismatch(
              utf8.encode(shown),
              utf8.encode(text),
            );
            if (mismatch != null) {
              problems.add('${ayah.address} ${form.name}: $mismatch');
            }
          } else {
            problems.add('${ayah.address} ${form.name}: not composed');
          }
          if (preview case Ok(value: (ayah: final shown, reference: _))) {
            final mismatch = byteMismatch(
              utf8.encode(shown.verbatim),
              ayah.stored,
            );
            if (mismatch != null) {
              problems.add('${ayah.address} ${form.name}: $mismatch');
            }
            if (shown != ayah.text) problems.add('${ayah.address}: not read');
          }
        }
      }
      expectNoProblems(problems);
    });

    test('previews nothing for a form with no format', () async {
      final address = QuranAddress(repository.riwaya, 1, 1);
      for (final form in [CopyForm.ayahOnly, CopyForm.withSurah]) {
        expect(
          await copyText.preview(address, form),
          isA<Failure<CopyPreview>>().having(
            (failure) => failure.error,
            'error',
            isA<CopyFormUnavailable>().having((e) => e.form, 'form', form),
          ),
        );
      }
    });

    test('copies the ayah of a word address', () async {
      final ayah = QuranAddress(repository.riwaya, 2, 1);
      final word = QuranAddress(repository.riwaya, 2, 1, 2);
      final ofAyah = await copyText.compose(ayah, CopyForm.withSurahAndNumber);
      final ofWord = await copyText.compose(word, CopyForm.withSurahAndNumber);
      expect((ofWord as Ok<String>).value, (ofAyah as Ok<String>).value);
    });

    test('fails for an address the pack does not hold', () async {
      for (final address in [
        QuranAddress(repository.riwaya, 1, 999),
        QuranAddress(repository.riwaya, 99, 1),
        QuranAddress('other', 1, 1),
      ]) {
        expect(
          await copyText.compose(address, CopyForm.withSurahAndNumber),
          isA<Failure<String>>().having(
            (failure) => failure.error,
            'error',
            isA<AddressNotInPack>(),
          ),
          reason: '$address',
        );
      }
    });
  });
}
