import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';

/// Every generated style, by name. The first test keeps this list equal to
/// the styles declared in the generated file, so a new one is not skipped.
const _styles = {
  'quranPage': AppTextStyles.quranPage,
  'quranAyah': AppTextStyles.quranAyah,
  'quranFocus': AppTextStyles.quranFocus,
  'display': AppTextStyles.display,
  'surahCard': AppTextStyles.surahCard,
  'surahHeader': AppTextStyles.surahHeader,
  'appTitle': AppTextStyles.appTitle,
  'screenTitle': AppTextStyles.screenTitle,
  'sectionTitle': AppTextStyles.sectionTitle,
  'tafsir': AppTextStyles.tafsir,
  'body': AppTextStyles.body,
  'bodyStrong': AppTextStyles.bodyStrong,
  'secondary': AppTextStyles.secondary,
  'caption': AppTextStyles.caption,
  'tabLabel': AppTextStyles.tabLabel,
};

const _quranStyles = {'quranPage', 'quranAyah', 'quranFocus'};

List<String> _declaredStyles() {
  final source = File('lib/ui/core/theme/tokens.g.dart').readAsStringSync();
  final body = RegExp(
    r'abstract final class AppTextStyles \{(.*?)\n\}',
    dotAll: true,
  ).firstMatch(source)![1]!;
  return [
    for (final match in RegExp(
      r'static const TextStyle (\w+)\s*=',
    ).allMatches(body))
      match[1]!,
  ];
}

void main() {
  test('the list holds every style of the generated file', () {
    expect(_declaredStyles(), hasLength(15));
    expect(_styles.keys, unorderedEquals(_declaredStyles()));
  });

  test('every style distributes leading evenly and adds no spacing', () {
    for (final MapEntry(key: name, value: style) in _styles.entries) {
      expect(
        style.leadingDistribution,
        TextLeadingDistribution.even,
        reason: name,
      );
      expect(style.letterSpacing, 0, reason: name);
    }
  });

  test('every style names one of the three families', () {
    for (final MapEntry(key: name, value: style) in _styles.entries) {
      expect(
        style.fontFamily,
        isIn(const [AppFonts.quran, AppFonts.kufi, AppFonts.sans]),
        reason: name,
      );
    }
  });

  test('Quran styles use the Quran font with no fallback', () {
    final quran = {
      for (final MapEntry(:key, :value) in _styles.entries)
        if (value.fontFamily == AppFonts.quran) key,
    };
    expect(quran, _quranStyles);
    for (final name in _quranStyles) {
      expect(_styles[name]!.fontFamilyFallback, isNull, reason: name);
    }
  });

  test('Reem Kufi styles fall back to the sans family only', () {
    final kufi = [
      for (final MapEntry(:key, :value) in _styles.entries)
        if (value.fontFamily == AppFonts.kufi) key,
    ];
    expect(kufi, isNotEmpty);
    for (final name in kufi) {
      expect(_styles[name]!.fontFamilyFallback, [AppFonts.sans], reason: name);
    }
  });
}
