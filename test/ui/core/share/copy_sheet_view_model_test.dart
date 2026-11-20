import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/copy_form.dart';
import 'package:holyquran/domain/models/pack_failure.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/share/ayah_copy_text.dart';
import 'package:holyquran/ui/core/share/copy_sheet_view_model.dart';
import 'package:holyquran/utils/result.dart';

import '../../../integrity/pack_integrity_suite.dart';
import 'share_test_pack.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

void main() {
  late PackUnderTest pack;

  setUpAll(() async {
    pack = await loadShareTestPack();
  });

  CopySheetViewModel viewModel(
    QuranAddress Function(String riwaya) address,
    List<String> copied, {
    Exception? clipboardFailure,
  }) {
    final repository = pack.openRepository();
    return CopySheetViewModel(
      address: address(repository.riwaya),
      copyText: AyahCopyText(repository, _l10n),
      copyToClipboard: (text) async {
        copied.add(text);
        return clipboardFailure == null
            ? const Ok(null)
            : Failure(clipboardFailure);
      },
    );
  }

  test('offers the three forms, the full one selected', () {
    final model = viewModel((riwaya) => QuranAddress(riwaya, 1, 1), []);
    addTearDown(model.dispose);
    expect(model.forms, CopyForm.values);
    expect(model.selected, CopyForm.withSurahAndNumber);
  });

  test('selecting the selected form notifies nothing', () {
    final model = viewModel((riwaya) => QuranAddress(riwaya, 1, 1), []);
    addTearDown(model.dispose);
    var notified = 0;
    model
      ..addListener(() => notified++)
      ..select(CopyForm.withSurahAndNumber);
    expect(notified, 0);
  });

  Future<void> loaded(CopySheetViewModel model) async {
    while (model.load.running || model.load.result == null) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  test('previews the selected form from the pack', () async {
    final model = viewModel((riwaya) => QuranAddress(riwaya, 2, 3, 1), []);
    addTearDown(model.dispose);
    expect(model.preview, isNull);
    var notified = 0;
    model.addListener(() => notified++);
    await loaded(model);
    expect(model.load.completed, isTrue);
    expect(notified, 1);
    final repository = pack.openRepository();
    final address = QuranAddress(repository.riwaya, 2, 3);
    final expected = await AyahCopyText(
      repository,
      _l10n,
    ).preview(address, model.selected);
    final (:ayah, :surahName, :ayahNumber) =
        (expected as Ok<CopyPreview>).value;
    final preview = model.preview!;
    expect(preview.ayah, ayah);
    expect(utf8.encode(preview.ayah.verbatim), utf8.encode(ayah.verbatim));
    expect(preview.surahName, surahName);
    expect(
      utf8.encode(preview.surahName!.verbatim),
      utf8.encode(surahName!.verbatim),
    );
    expect(preview.ayahNumber, ayahNumber);
    expect(ayahNumber, 3);
  });

  test('a failed read leaves no preview', () async {
    final model = viewModel((riwaya) => QuranAddress(riwaya, 9, 1), []);
    addTearDown(model.dispose);
    await loaded(model);
    expect(model.load.error, isTrue);
    expect(model.preview, isNull);
  });

  test('closing before the preview is read throws nothing', () async {
    final model = viewModel((riwaya) => QuranAddress(riwaya, 1, 1), []);
    final load = model.load;
    expect(load.running, isTrue);
    model.dispose();
    while (load.running) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(load.completed, isTrue);
  });

  test('copies the text the composer reads from the pack', () async {
    final copied = <String>[];
    final model = viewModel((riwaya) => QuranAddress(riwaya, 2, 2), copied);
    addTearDown(model.dispose);
    final repository = pack.openRepository();
    final expected = await AyahCopyText(
      repository,
      _l10n,
    ).compose(QuranAddress(repository.riwaya, 2, 2), model.selected);
    await model.copy.execute();
    expect(model.copy.completed, isTrue);
    expect(copied, hasLength(1));
    expect(
      utf8.encode(copied.single),
      utf8.encode((expected as Ok<String>).value),
    );
  });

  test('copies and previews the form selected', () async {
    final copied = <String>[];
    final model = viewModel((riwaya) => QuranAddress(riwaya, 2, 2), copied);
    addTearDown(model.dispose);
    await loaded(model);
    final repository = pack.openRepository();
    final address = QuranAddress(repository.riwaya, 2, 2);
    final copyText = AyahCopyText(repository, _l10n);
    var notified = 0;
    model.addListener(() => notified++);
    // Each form other than the one selected first, then back to that one, so
    // that every selection is a change.
    final initial = model.selected;
    final order = [
      for (final form in CopyForm.values)
        if (form != initial) form,
      initial,
    ];
    for (final form in order) {
      model.select(form);
      expect(model.selected, form);
      final expected = await copyText.preview(address, form);
      expect(model.preview, (expected as Ok<CopyPreview>).value);
      await model.copy.execute();
      final composed = await copyText.compose(address, form);
      expect(
        utf8.encode(copied.last),
        utf8.encode((composed as Ok<String>).value),
        reason: form.name,
      );
    }
    expect(notified, CopyForm.values.length);
    expect(copied, hasLength(CopyForm.values.length));
  });

  test('reports a failed read and copies nothing', () async {
    final copied = <String>[];
    final model = viewModel((riwaya) => QuranAddress(riwaya, 9, 1), copied);
    addTearDown(model.dispose);
    await model.copy.execute();
    expect(model.copy.error, isTrue);
    expect(
      (model.copy.result! as Failure<void>).error,
      isA<AddressNotInPack>(),
    );
    expect(copied, isEmpty);
  });

  test('reports a failed clipboard', () async {
    const failure = FormatException('synthetic');
    final model = viewModel(
      (riwaya) => QuranAddress(riwaya, 1, 1),
      [],
      clipboardFailure: failure,
    );
    addTearDown(model.dispose);
    await model.copy.execute();
    expect((model.copy.result! as Failure<void>).error, failure);
  });

  test('closing while a copy runs throws nothing, and the copy ends', () async {
    final copied = <String>[];
    final model = viewModel((riwaya) => QuranAddress(riwaya, 1, 1), copied);
    final copy = model.copy;
    final done = copy.execute();
    expect(copy.running, isTrue);
    model.dispose();
    await done;
    expect(copy.completed, isTrue);
    expect(copied, hasLength(1));
  });
}
