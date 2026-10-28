import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/surah_name.dart';

import '../../../../testing/golden.dart';

// Synthetic, never a real surah name. Spaces at both ends, a double space, a
// combining mark and a direction mark would be lost to any trimming or
// normalising.
const _value = ' اسمَ  تجريبي‏ ';
const _name = PackText.fromPack(_value);
const _ayah = 255;

final _style = AppTextStyles.surahHeader.copyWith(
  color: AppColors.paper.primary,
);

/// The ARB templates, read from the file so the test types no template.
final _templates =
    jsonDecode(File('lib/l10n/app_ar.arb').readAsStringSync())
        as Map<String, Object?>;

// The copy reference names its placeholders as the copy format does.
String _filled(String key) => (_templates[key]! as String)
    .replaceAll(RegExp(r'\{(name|surah)\}'), _value)
    .replaceAll(RegExp(r'\{(ayah|number)\}'), arabicDigits(_ayah));

final _expected = {
  SurahNameFormat.name: _value,
  SurahNameFormat.titled: _filled('surahTitle'),
  SurahNameFormat.withAyah: _filled('surahAyahReference'),
  SurahNameFormat.titledWithAyah: _filled('surahTitleAyahReference'),
  SurahNameFormat.copyReference: _filled('copyReferenceFull'),
};

bool _hasAyah(SurahNameFormat format) => switch (format) {
  SurahNameFormat.withAyah ||
  SurahNameFormat.titledWithAyah ||
  SurahNameFormat.copyReference => true,
  SurahNameFormat.name || SurahNameFormat.titled => false,
};

SurahName _surahName(SurahNameFormat format) => SurahName(
  _name,
  style: _style,
  format: format,
  ayah: _hasAyah(format) ? _ayah : null,
);

Future<void> _pump(WidgetTester tester, Widget child) =>
    tester.pumpWidget(goldenApp(ReadingTheme.paper, child));

RenderParagraph _paragraph(WidgetTester tester) =>
    tester.renderObject<RenderParagraph>(find.byType(RichText));

void main() {
  test('every template holds the name once, the ayah formats the ayah', () {
    for (final (key, name, ayah) in [
      ('surahTitle', '{name}', null),
      ('surahAyahReference', '{name}', '{ayah}'),
      ('surahTitleAyahReference', '{name}', '{ayah}'),
      ('copyReferenceFull', '{surah}', '{number}'),
    ]) {
      final template = _templates[key]! as String;
      expect(
        RegExp(r'\{\w+\}').allMatches(template),
        hasLength(ayah == null ? 1 : 2),
        reason: key,
      );
      expect(name.allMatches(template), hasLength(1), reason: key);
      if (ayah != null) {
        expect(ayah.allMatches(template), hasLength(1), reason: key);
      }
    }
  });

  for (final format in SurahNameFormat.values) {
    testWidgets('${format.name}: draws the template with the whole name', (
      tester,
    ) async {
      await _pump(tester, _surahName(format));

      final drawn = _paragraph(tester).text.toPlainText();
      expect(drawn, _expected[format]);
      expect(drawn, contains(_value));
      expect(drawn, isNot(matches(RegExp('[0-9]'))));
    });
  }

  testWidgets('substitutes the very string it was given', (tester) async {
    final name = PackText.fromPack(String.fromCharCodes(_value.codeUnits));
    await _pump(tester, SurahName(name, style: _style));

    final span = _paragraph(tester).text as TextSpan;
    expect(span.text, _value);
    expect(span.text!.codeUnits, _value.codeUnits);
  });

  testWidgets('uses the given style and alignment, Arabic, right to left', (
    tester,
  ) async {
    await _pump(
      tester,
      SurahName(_name, style: _style, textAlign: TextAlign.center),
    );

    final paragraph = _paragraph(tester);
    final style = paragraph.text.style!;
    expect(style.fontFamily, AppFonts.kufi);
    expect(style.fontSize, AppTextStyles.surahHeader.fontSize);
    expect(style.color, AppColors.paper.primary);
    expect(paragraph.textAlign, TextAlign.center);
    expect(paragraph.textDirection, TextDirection.rtl);
    expect(paragraph.locale, const Locale('ar'));
  });

  testWidgets('is never cut to a line limit or an ellipsis', (tester) async {
    await _pump(
      tester,
      DefaultTextStyle(
        style: AppTextStyles.body,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        child: SizedBox(
          width: 120,
          child: _surahName(SurahNameFormat.titledWithAyah),
        ),
      ),
    );

    final paragraph = _paragraph(tester);
    expect(paragraph.maxLines, isNull);
    expect(paragraph.overflow, isNot(TextOverflow.ellipsis));
    expect(paragraph.softWrap, isTrue);
    expect(paragraph.didExceedMaxLines, isFalse);
  });

  testWidgets('wraps without overflow at 200% on a 360 wide screen', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(360, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    for (final format in SurahNameFormat.values) {
      await _pump(tester, _surahName(format));
      expect(tester.takeException(), isNull, reason: format.name);
      expect(_paragraph(tester).textScaler.scale(10), 20);
    }
  });

  testWidgets('is read by screen readers as what it draws', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, _surahName(SurahNameFormat.titledWithAyah));

    expect(
      find.bySemanticsLabel(_expected[SurahNameFormat.titledWithAyah]!),
      findsOneWidget,
    );
    handle.dispose();
  });

  test('takes an ayah exactly in the formats that carry one', () {
    for (final format in SurahNameFormat.values) {
      expect(
        () => SurahName(_name, style: _style, format: format),
        _hasAyah(format) ? throwsAssertionError : returnsNormally,
        reason: format.name,
      );
      expect(
        () => SurahName(_name, style: _style, format: format, ayah: 1),
        _hasAyah(format) ? returnsNormally : throwsAssertionError,
        reason: format.name,
      );
    }
  });
  group('span', () {
    final l10n = lookupAppLocalizations(const Locale('ar'));
    const style = TextStyle(inherit: false, fontSize: 15);

    for (final format in SurahNameFormat.values) {
      test('${format.name}: the template with the whole name, in the given '
          'style', () {
        final span = SurahName.span(
          _name,
          format: format,
          ayah: _hasAyah(format) ? _ayah : null,
          style: style,
          l10n: l10n,
        );
        expect(span.text, _expected[format]);
        expect(utf8.encode(span.text!), utf8.encode(_expected[format]!));
        expect(span.style, same(style));
        expect(span.children, isNull);
      });
    }

    test('substitutes the very string it was given', () {
      final name = PackText.fromPack(String.fromCharCodes(_value.codeUnits));
      final span = SurahName.span(
        name,
        format: SurahNameFormat.name,
        style: style,
        l10n: l10n,
      );
      expect(identical(span.text, name.verbatim), isTrue);
    });

    test('takes an ayah exactly in the formats that carry one, and only a '
        'style that does not inherit', () {
      for (final format in SurahNameFormat.values) {
        expect(
          () => SurahName.span(
            _name,
            format: format,
            ayah: _hasAyah(format) ? null : 1,
            style: style,
            l10n: l10n,
          ),
          throwsAssertionError,
          reason: format.name,
        );
      }
      expect(
        () => SurahName.span(
          _name,
          format: SurahNameFormat.name,
          style: const TextStyle(fontSize: 15),
          l10n: l10n,
        ),
        throwsAssertionError,
      );
    });
  });
}
