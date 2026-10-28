import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/edition_map.dart';
import 'package:holyquran/domain/models/go_to_error.dart';
import 'package:holyquran/domain/models/go_to_target.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/ui/features/index/view_models/go_to_view_model.dart';

import 'index_fixture.dart';

void main() {
  late Directory root;
  late IndexFixture fixture;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('go_to_view_model_test');
    fixture = await IndexFixture.load(root);
  });
  tearDownAll(() async {
    fixture.close();
    await root.delete(recursive: true);
  });

  GoToViewModel model() {
    final model = GoToViewModel(index: fixture.index);
    addTearDown(model.dispose);
    return model;
  }

  QuranAddress at(int surah, int ayah) =>
      QuranAddress(fixture.index.riwaya, surah, ayah);

  test('offers the six targets of the PRD, the surah first', () {
    expect(GoToChoice.values.map((choice) => choice.name), [
      'surah',
      'ayah',
      'page',
      'juz',
      'hizb',
      'rub',
    ]);
    expect(model().choice, GoToChoice.surah);
    expect(GoToChoice.values.where((choice) => choice.asksAyah), [
      GoToChoice.ayah,
    ]);
  });

  test('a surah opens at its first ayah, in any digit system', () {
    for (final number in ['2', '٢', '۲', ' 2 ']) {
      expect(model().submit(number), GoToSurah(at(2, 1)), reason: number);
    }
  });

  test('a surah and an ayah open at that ayah, in any digit system', () {
    final m = model()..select(GoToChoice.ayah);
    expect(m.submit('2', ayah: '5'), GoToAyah(at(2, 5)));
    expect(m.submit('٢', ayah: '٥'), GoToAyah(at(2, 5)));
    expect(m.submit('۲', ayah: '۵'), GoToAyah(at(2, 5)));
    expect(m.submit('2', ayah: '٥'), GoToAyah(at(2, 5)));
  });

  test('the last ayah of a surah is valid; the next one is not', () {
    final m = model()..select(GoToChoice.ayah);
    final last = fixture.surahs[1].ayahCount;
    expect(m.submit('2', ayah: '$last'), GoToAyah(at(2, last)));
    expect(m.submit('2', ayah: '${last + 1}'), isNull);
    expect(m.error, NoSuchAyah(surah: 2, ayah: last + 1, ayahCount: last));
  });

  for (final (choice, division) in [
    (GoToChoice.page, Division.page),
    (GoToChoice.juz, Division.juz),
    (GoToChoice.hizb, Division.hizb),
    (GoToChoice.rub, Division.rub),
  ]) {
    test('every ${division.name} of the pack opens at its first ayah, '
        'in any digit system', () {
      final m = model()..select(choice);
      for (var number = 1; number <= fixture.index.count(division); number++) {
        final first = fixture.index.firstAyah(division, number);
        final target = GoToDivision(division, number, first);
        expect(m.submit('$number'), target);
        expect(m.submit(_indic(number)), target);
        expect(m.submit(_extended(number)), target);
      }
    });

    test('a ${division.name} the pack does not have is refused with its '
        'number and the count', () {
      final count = fixture.index.count(division);
      final m = model()..select(choice);
      expect(m.submit('${count + 1}'), isNull);
      expect(
        m.error,
        DivisionOutOfRange(division: division, number: count + 1, count: count),
      );
      expect(m.submit('0'), isNull);
      expect(
        m.error,
        DivisionOutOfRange(division: division, number: 0, count: count),
      );
    });
  }

  test('a surah the pack does not have is refused', () {
    final m = model();
    final count = fixture.index.surahCount;
    expect(m.submit('${count + 1}'), isNull);
    expect(m.error, NoSuchSurah(surah: count + 1, surahCount: count));
  });

  test('input that is not a number is unreadable', () {
    final m = model();
    for (final input in ['', '  ', 'abc', '2x', '-1', '1.5']) {
      expect(m.submit(input), isNull, reason: input);
      expect(m.error, const UnreadableGoTo(), reason: input);
    }
  });

  test('an ayah target with no ayah typed is unreadable', () {
    final m = model()..select(GoToChoice.ayah);
    expect(m.submit('2'), isNull);
    expect(m.error, const UnreadableGoTo());
    expect(m.submit('2', ayah: 'x'), isNull);
    expect(m.error, const UnreadableGoTo());
  });

  test('an ayah typed for another target is ignored', () {
    expect(model().submit('2', ayah: '5'), GoToSurah(at(2, 1)));
  });

  test('the error stays until the input or the target changes', () {
    final m = model();
    var notified = 0;
    m.addListener(() => notified++);
    m.submit('x');
    expect(m.error, isNotNull);
    expect(notified, 1);
    m.clearError();
    expect(m.error, isNull);
    expect(notified, 2);
    m.clearError();
    expect(notified, 2);
    m.submit('x');
    m.select(GoToChoice.page);
    expect(m.error, isNull);
    expect(m.choice, GoToChoice.page);
  });

  test('a valid input clears an earlier error', () {
    final m = model()..submit('x');
    expect(m.submit('1'), isNotNull);
    expect(m.error, isNull);
  });

  test('names a surah from the pack, or none outside it', () {
    final m = model();
    expect(m.surahName(2), fixture.surahs[1].name);
    expect(m.surahName(0), isNull);
    expect(m.surahName(fixture.index.surahCount + 1), isNull);
  });
}

String _indic(int number) => String.fromCharCodes(
  '$number'.codeUnits.map((unit) => unit - 0x30 + 0x660),
);

String _extended(int number) => String.fromCharCodes(
  '$number'.codeUnits.map((unit) => unit - 0x30 + 0x6F0),
);
