import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/edition_map.dart';
import 'package:holyquran/domain/models/go_to_error.dart';
import 'package:holyquran/domain/models/go_to_target.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/quran_structure.dart';
import 'package:holyquran/domain/use_cases/parse_direct_jump.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/utils/result.dart';

import '../../../testing/fakes/fake_address_input_repository.dart';

// A synthetic edition: three surahs of 7, 20 and 5 ayat, with made-up
// divisions and names. None of its numbers or names are a real edition's.

QuranAddress _at(int surah, int ayah) => QuranAddress('synthetic', surah, ayah);

final class _Structure implements QuranStructure {
  static const _ayahCounts = [7, 20, 5];

  final _map = EditionMap(
    edition: 'synthetic',
    starts: {
      Division.juz: [_at(1, 1), _at(2, 1)],
      Division.hizb: [_at(1, 1), _at(1, 5), _at(2, 1), _at(3, 1)],
      Division.rub: [_at(1, 1), _at(1, 4), _at(2, 1), _at(2, 10), _at(3, 1)],
      Division.page: [_at(1, 1), _at(1, 6), _at(2, 4), _at(2, 15), _at(3, 2)],
    },
    sajdas: const {},
  );

  @override
  String get riwaya => 'synthetic';

  @override
  int get surahCount => _ayahCounts.length;

  @override
  int ayahCount(int surah) => _ayahCounts[surah - 1];

  @override
  int? nextSurah(int surah) => surah < surahCount ? surah + 1 : null;

  @override
  int count(Division division) => _map.count(division);

  @override
  QuranAddress firstAyah(Division division, int number) =>
      _map.startOf(division, number);

  @override
  int numberAt(Division division, QuranAddress address) =>
      _map.numberAt(division, address);
}

const _words = DirectJumpWords(
  surah: 'chapter',
  page: 'leaf',
  juz: 'part',
  hizb: 'half',
  rub: 'quarter',
);

/// A synthetic Arabic-script name: two words that read "test text".
const _arabicName = '\u0646\u0635 \u062A\u062C\u0631\u064A\u0628\u064A';

const _names = {'Synthetic one': 1, 'Synthetic two words': 2, _arabicName: 3};

const _digitSystems = {
  'Western': 0x0030,
  'Arabic-Indic': 0x0660,
  'extended Arabic-Indic': 0x06F0,
};

String _digits(String western, int zero) => String.fromCharCodes(
  western.codeUnits.map(
    (unit) => unit >= 0x30 && unit <= 0x39 ? unit - 0x30 + zero : unit,
  ),
);

final class _LookupFailed implements Exception {
  const _LookupFailed();
}

void main() {
  final structure = _Structure();
  late FakeAddressInputRepository names;

  setUp(() => names = FakeAddressInputRepository(names: _names));

  Future<Object?> jump(String text, {DirectJumpWords words = _words}) async =>
      switch (await parseDirectJump(
        text,
        words: words,
        structure: structure,
        surahNamed: names.surahNamed,
      )) {
        null => null,
        Ok(:final value) => value,
        Failure(:final error) => error,
      };

  Future<void> expectJumps(Map<String, Object?> cases) async {
    for (final MapEntry(key: text, value: expected) in cases.entries) {
      expect(await jump(text), expected, reason: '"$text"');
    }
  }

  for (final MapEntry(key: system, value: zero) in _digitSystems.entries) {
    String d(String western) => _digits(western, zero);

    group('in $system digits', () {
      test('reads surah:ayah', () async {
        await expectJumps({
          d('2:15'): GoToAyah(_at(2, 15)),
          d('1:1'): GoToAyah(_at(1, 1)),
          d('03:005'): GoToAyah(_at(3, 5)),
          d(' 2 : 15 '): GoToAyah(_at(2, 15)),
        });
      });

      test('reads a name and an ayah', () async {
        await expectJumps({
          'Synthetic one ${d('3')}': GoToAyah(_at(1, 3)),
          'Synthetic two words ${d('20')}': GoToAyah(_at(2, 20)),
          '$_arabicName ${d('5')}': GoToAyah(_at(3, 5)),
          '  Synthetic one\t${d('7')}  ': GoToAyah(_at(1, 7)),
        });
      });

      test('reads the surah word with a number or a name', () async {
        await expectJumps({
          'chapter ${d('2')}': GoToSurah(_at(2, 1)),
          'chapter ${d('2')} ${d('15')}': GoToAyah(_at(2, 15)),
          'chapter ${d('2:15')}': GoToAyah(_at(2, 15)),
          'chapter ${d('2 : 15')}': GoToAyah(_at(2, 15)),
          'chapter Synthetic one': GoToSurah(_at(1, 1)),
          'chapter $_arabicName': GoToSurah(_at(3, 1)),
          'chapter Synthetic two words ${d('4')}': GoToAyah(_at(2, 4)),
        });
      });

      test('reads the division words', () async {
        await expectJumps({
          'leaf ${d('3')}': GoToDivision(Division.page, 3, _at(2, 4)),
          'part ${d('2')}': GoToDivision(Division.juz, 2, _at(2, 1)),
          'half ${d('2')}': GoToDivision(Division.hizb, 2, _at(1, 5)),
          'quarter ${d('4')}': GoToDivision(Division.rub, 4, _at(2, 10)),
          ' leaf  ${d('05')} ': GoToDivision(Division.page, 5, _at(3, 2)),
        });
      });

      test('names the reason a jump is refused', () async {
        await expectJumps({
          d('2:21'): const NoSuchAyah(surah: 2, ayah: 21, ayahCount: 20),
          d('1:0'): const NoSuchAyah(surah: 1, ayah: 0, ayahCount: 7),
          'Synthetic one ${d('300')}': const NoSuchAyah(
            surah: 1,
            ayah: 300,
            ayahCount: 7,
          ),
          'chapter ${d('3')} ${d('6')}': const NoSuchAyah(
            surah: 3,
            ayah: 6,
            ayahCount: 5,
          ),
          d('4:1'): const NoSuchSurah(surah: 4, surahCount: 3),
          d('0:1'): const NoSuchSurah(surah: 0, surahCount: 3),
          'chapter ${d('9')}': const NoSuchSurah(surah: 9, surahCount: 3),
          'leaf ${d('6')}': const DivisionOutOfRange(
            division: Division.page,
            number: 6,
            count: 5,
          ),
          'part ${d('0')}': const DivisionOutOfRange(
            division: Division.juz,
            number: 0,
            count: 2,
          ),
          'half ${d('5')}': const DivisionOutOfRange(
            division: Division.hizb,
            number: 5,
            count: 4,
          ),
          'quarter ${d('6')}': const DivisionOutOfRange(
            division: Division.rub,
            number: 6,
            count: 5,
          ),
          d('1234567890:1'): const UnreadableGoTo(),
          d('1:1234567890'): const UnreadableGoTo(),
          'leaf ${d('1234567890')}': const UnreadableGoTo(),
          'chapter ${d('1234567890')}': const UnreadableGoTo(),
          'Synthetic one ${d('1234567890')}': const UnreadableGoTo(),
        });
      });
    });
  }

  test('returns nothing for text that is not a jump', () async {
    for (final text in [
      '',
      '   ',
      'mercy',
      'two words',
      '2',
      '2 15',
      '2:',
      ':15',
      '2:15:3',
      '2:x',
      'x:2',
      '2-15',
      'Synthetic one',
      'Unknown name 3',
      'Synthetic  one 3',
      'synthetic one 3',
      'leaf',
      'leaf three',
      'leaf 3 4',
      'leaf3',
      'LEAF 3',
      'chapter',
      'chapter unknown',
      'chapter unknown 3',
      'part Synthetic one',
      '3 leaf',
    ]) {
      expect(await jump(text), isNull, reason: '"$text"');
    }
  });

  test('passes the name to the lookup as typed, without the spaces around '
      'the text', () async {
    await jump('  Synthetic  two words 3 ');
    await jump('chapter  Synthetic one ');
    expect(names.lookups, ['Synthetic  two words', 'Synthetic one']);
  });

  test('looks up no name for a number or division form', () async {
    await jump('2:15');
    await jump('leaf 3');
    await jump('chapter 2');
    await jump('chapter 2 15');
    await jump('chapter 2:15');
    expect(names.lookups, isEmpty);
  });

  test('returns a failed name lookup as its failure', () async {
    names.failure = const _LookupFailed();
    expect(await jump('Synthetic one 3'), const _LookupFailed());
    expect(await jump('chapter Synthetic one'), const _LookupFailed());
    expect(await jump('2:15'), GoToAyah(_at(2, 15)));
  });

  test('recognises the words of the interface', () async {
    final l10n = lookupAppLocalizations(const Locale('ar'));
    final words = DirectJumpWords(
      surah: l10n.goToSurah,
      page: l10n.goToPage,
      juz: l10n.goToJuz,
      hizb: l10n.goToHizb,
      rub: l10n.goToRub,
    );
    final three = _digits('3', 0x0660);
    expect(
      await jump('${l10n.goToPage} $three', words: words),
      GoToDivision(Division.page, 3, _at(2, 4)),
    );
    expect(
      await jump('${l10n.goToJuz} 2', words: words),
      GoToDivision(Division.juz, 2, _at(2, 1)),
    );
    expect(
      await jump('${l10n.goToHizb} 4', words: words),
      GoToDivision(Division.hizb, 4, _at(3, 1)),
    );
    expect(
      await jump('${l10n.goToRub} 5', words: words),
      GoToDivision(Division.rub, 5, _at(3, 1)),
    );
    expect(
      await jump('${l10n.goToSurah} $three', words: words),
      GoToSurah(_at(3, 1)),
    );
  });
}
