import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/data/repositories/quran_text_repository.dart';
import 'package:holyquran/domain/models/edition_map.dart';
import 'package:holyquran/domain/models/mark_span.dart';
import 'package:holyquran/domain/models/pack_manifest.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/surah_info.dart';
import 'package:holyquran/domain/models/word_span.dart';
import 'package:holyquran/ui/core/metrics/index_metrics.dart';
import 'package:holyquran/ui/features/index/view_models/context_sheet_view_model.dart';
import 'package:holyquran/utils/result.dart';

import 'index_fixture.dart';

/// The pack's repository that counts the ayat it is asked for, and can fail.
final class _Counting implements QuranTextRepository {
  _Counting(this._inner);

  final QuranTextRepository _inner;
  final asked = <int>[];
  bool failing = false;

  @override
  String get riwaya => _inner.riwaya;

  @override
  PackFont get font => _inner.font;

  @override
  Future<Result<PackText>> ayahText(QuranAddress address) async {
    asked.add(address.ayah);
    if (failing) return Failure(Exception('unreadable'));
    return _inner.ayahText(address);
  }

  @override
  Future<Result<List<SurahInfo>>> surahs() => _inner.surahs();

  @override
  Future<Result<PackText?>> basmala(int surah) => _inner.basmala(surah);

  @override
  Future<Result<Set<int>>> basmalaSurahs() => _inner.basmalaSurahs();

  @override
  Future<Result<List<WordSpan>>> words(QuranAddress address) =>
      _inner.words(address);

  @override
  Future<Result<List<MarkSpan>>> marks(QuranAddress address) =>
      _inner.marks(address);

  @override
  Future<Result<EditionMap>> editionMap() => _inner.editionMap();

  @override
  Future<Result<bool>> contains(QuranAddress address) =>
      _inner.contains(address);
}

void main() {
  late Directory root;
  late IndexFixture fixture;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('context_view_model_test');
    fixture = await IndexFixture.load(root);
  });
  tearDownAll(() async {
    fixture.close();
    await root.delete(recursive: true);
  });

  QuranAddress at(int surah, int ayah) =>
      QuranAddress(fixture.index.riwaya, surah, ayah);

  Future<ContextSheetViewModel> open(
    QuranAddress address, {
    _Counting? text,
  }) async {
    final model = ContextSheetViewModel(
      address: address,
      text: text ?? _Counting(fixture.text),
      index: fixture.index,
    );
    addTearDown(model.dispose);
    await pumpEventQueue();
    return model;
  }

  /// The numbers of the ayat the passage shows, from its first on.
  List<int> shown(ContextSheetViewModel model) {
    final passage = model.passage!;
    return [
      for (var k = 0; k < passage.text.ayat.length; k++) passage.firstAyah + k,
    ];
  }

  int indexOf(int? size) => IndexMetrics.contextAmounts.indexOf(size);

  test('offers the ayah, 3 ayat, 5 ayat and the surah, the ayah first', () {
    expect(IndexMetrics.contextAmounts, [1, 3, 5, null]);
  });

  test('shows the ayah alone at first, between its markers selected', () async {
    final model = await open(at(2, 5));
    expect(model.amount, 0);
    expect(shown(model), [5]);
    expect(model.passage!.selectedAyah, 5);
    expect(model.address, at(2, 5));
    expect(model.surahName, fixture.surahs[1].name);
  });

  test('is empty until the ayat are read', () async {
    final model = ContextSheetViewModel(
      address: at(2, 5),
      text: fixture.text,
      index: fixture.index,
    );
    addTearDown(model.dispose);
    expect(model.passage, isNull);
    await pumpEventQueue();
    expect(model.passage, isNotNull);
  });

  test('3 ayat are one before and one after, 5 are two and two', () async {
    final model = await open(at(2, 6));
    model.select(indexOf(3));
    await pumpEventQueue();
    expect(shown(model), [5, 6, 7]);
    model.select(indexOf(5));
    await pumpEventQueue();
    expect(shown(model), [4, 5, 6, 7, 8]);
    expect(model.passage!.selectedAyah, 6);
  });

  test('keeps the count at the start and the end of a surah by moving the '
      'window along', () async {
    final last = fixture.surahs[1].ayahCount;
    final start = await open(at(2, 1));
    start.select(indexOf(3));
    await pumpEventQueue();
    expect(shown(start), [1, 2, 3]);
    start.select(indexOf(5));
    await pumpEventQueue();
    expect(shown(start), [1, 2, 3, 4, 5]);

    final end = await open(at(2, last));
    end.select(indexOf(5));
    await pumpEventQueue();
    expect(shown(end), [last - 4, last - 3, last - 2, last - 1, last]);
    expect(end.passage!.selectedAyah, last);
  });

  test('a surah shorter than the choice shows all of it', () async {
    final short = fixture.surahs[2].ayahCount;
    final model = await open(at(3, 2));
    model.select(indexOf(5));
    await pumpEventQueue();
    expect(shown(model), [for (var a = 1; a <= short; a++) a]);
  });

  test('the surah shows every ayah of it', () async {
    final all = fixture.surahs[1].ayahCount;
    final model = await open(at(2, 7));
    model.select(indexOf(null));
    await pumpEventQueue();
    expect(shown(model), [for (var a = 1; a <= all; a++) a]);
    expect(model.passage!.selectedAyah, 7);
  });

  test('hands over the pack\'s text of each ayah, whole', () async {
    final model = await open(at(2, 6));
    model.select(indexOf(3));
    await pumpEventQueue();
    final ayat = model.passage!.text.ayat;
    for (final (k, ayah) in [5, 6, 7].indexed) {
      final stored = await fixture.text.ayahText(at(2, ayah));
      expect(ayat[k].text, (stored as Ok<PackText>).value);
      final words = await fixture.text.words(at(2, ayah));
      expect(ayat[k].words, (words as Ok<List<WordSpan>>).value);
    }
  });

  test('reads an ayah once however often the choice changes', () async {
    final text = _Counting(fixture.text);
    final model = await open(at(2, 6), text: text);
    expect(text.asked, [6]);
    model.select(indexOf(3));
    await pumpEventQueue();
    expect(text.asked, [6, 5, 7]);
    model.select(indexOf(1));
    await pumpEventQueue();
    model.select(indexOf(3));
    await pumpEventQueue();
    expect(text.asked, [6, 5, 7]);
  });

  test('tells the screen of a choice and of the ayat', () async {
    final model = await open(at(2, 6));
    var notified = 0;
    model.addListener(() => notified++);
    model
      ..select(indexOf(3))
      ..select(indexOf(3));
    expect(notified, 1);
    await pumpEventQueue();
    expect(notified, 2);
  });

  test('the last choice wins over one still being read', () async {
    final model = await open(at(2, 6));
    model
      ..select(indexOf(null))
      ..select(indexOf(3));
    await pumpEventQueue();
    expect(model.amount, indexOf(3));
    expect(shown(model), [5, 6, 7]);
  });

  test('shows no text when the pack cannot give it', () async {
    final text = _Counting(fixture.text)..failing = true;
    final model = await open(at(2, 6), text: text);
    expect(model.passage, isNull);
  });

  test('says which addresses it can show', () {
    final index = fixture.index;
    expect(ContextSheetViewModel.canShow(index, at(2, 12)), isTrue);
    expect(ContextSheetViewModel.canShow(index, at(2, 13)), isFalse);
    expect(ContextSheetViewModel.canShow(index, at(4, 1)), isFalse);
    expect(
      ContextSheetViewModel.canShow(index, QuranAddress('warsh', 2, 1)),
      isFalse,
    );
  });

  test('a word address is the ayah it is in', () async {
    final model = await open(QuranAddress(fixture.index.riwaya, 2, 6, 2));
    expect(model.address, at(2, 6));
    expect(shown(model), [6]);
  });
}
