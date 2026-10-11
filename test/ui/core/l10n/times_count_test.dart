import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/l10n/times_count.dart';

/// The four forms of the reference `timesCount` in
/// design/design-system/components/src/index.jsx.
enum _Form { one, two, few, other }

/// Which form the reference gives for each value: the singular-one form for
/// 1, the dual for 2, the plural when the last two digits are 3 to 10, the
/// counted singular otherwise (0 and 11 to 99 included).
final _table = {
  0: _Form.other,
  1: _Form.one,
  2: _Form.two,
  for (var n = 3; n <= 10; n++) n: _Form.few,
  for (var n = 11; n <= 99; n++) n: _Form.other,
  100: _Form.other,
  101: _Form.other,
  102: _Form.other,
  103: _Form.few,
  110: _Form.few,
  111: _Form.other,
  1000: _Form.other,
};

/// The case texts of the `timesCount` message, read from the ARB so the test
/// types no Arabic.
Map<_Form, String> _formsFromArb() {
  final arb =
      jsonDecode(File('lib/l10n/app_ar.arb').readAsStringSync())
          as Map<String, Object?>;
  final message = arb['timesCount']! as String;
  final cases = {
    for (final match in RegExp(
      r'(=1|=2|few|other)\{((?:[^{}]|\{digits\})*)\}',
    ).allMatches(message))
      match[1]!: match[2]!,
  };
  return {
    _Form.one: cases['=1']!,
    _Form.two: cases['=2']!,
    _Form.few: cases['few']!,
    _Form.other: cases['other']!,
  };
}

void main() {
  final l10n = lookupAppLocalizations(const Locale('ar'));
  final forms = _formsFromArb();

  test('the ARB has four distinct forms, the counted two with digits', () {
    expect(forms.values.toSet(), hasLength(4));
    expect(forms[_Form.one], isNot(contains('{digits}')));
    expect(forms[_Form.two], isNot(contains('{digits}')));
    expect(forms[_Form.few], contains('{digits}'));
    expect(forms[_Form.other], contains('{digits}'));
  });

  for (final MapEntry(key: n, value: form) in _table.entries) {
    test('$n takes the ${form.name} form, as the reference', () {
      final expected = forms[form]!.replaceAll('{digits}', arabicDigits(n));
      expect(timesCount(l10n, n), expected);
    });
  }

  test('shows no ASCII digit', () {
    for (final n in _table.keys) {
      expect(timesCount(l10n, n), isNot(matches(RegExp('[0-9]'))));
    }
  });

  test('rejects a negative count', () {
    expect(() => timesCount(l10n, -1), throwsArgumentError);
  });
}
