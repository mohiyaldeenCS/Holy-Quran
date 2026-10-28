import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/quran_text.dart';
import 'package:holyquran/ui/core/widgets/tafsir_text.dart';

import '../../../../testing/golden.dart';

// Synthetic. The spaces at both ends, the double space, the combining mark,
// the direction mark and the line break would be lost to any trimming,
// joining or normalising; the ornate brackets stand for an ayah quoted
// inside a passage.
const _value = ' نص ﴿ تجريبي ﴾  بعده\u064E\u200F\nسطر ثانٍ ';
const _text = PackText.fromPack(_value);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  ReadingTheme theme = ReadingTheme.paper,
}) async {
  tester.view
    ..physicalSize = const Size(360, 640)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(goldenApp(theme, child));
}

void main() {
  testWidgets('draws the text whole, as the pack gives it', (tester) async {
    await _pump(tester, const TafsirText(_text));
    final text = tester.widget<Text>(find.byType(Text));
    expect(text.data, _value);
    expect(text.textDirection, TextDirection.rtl);
  });

  testWidgets('sets an ayah quoted inside it in the interface font, '
      'not as Quran text', (tester) async {
    await _pump(tester, const TafsirText(_text));
    final style = tester.widget<Text>(find.byType(Text)).style!;
    expect(style.fontFamily, AppFonts.sans);
    expect(style.fontFamily, isNot(AppFonts.quran));
    expect(style.fontSize, AppTextStyles.tafsir.fontSize);
    expect(style.height, AppTextStyles.tafsir.height);
    expect(find.byType(QuranText), findsNothing);
  });

  for (final theme in ReadingTheme.values) {
    testWidgets('is ink in ${theme.name}', (tester) async {
      await _pump(tester, const TafsirText(_text), theme: theme);
      final colors = tester.element(find.byType(Text)).colors;
      expect(tester.widget<Text>(find.byType(Text)).style!.color, colors.ink);
    });
  }

  testWidgets('takes another style and colour for a fact of the book', (
    tester,
  ) async {
    await _pump(
      tester,
      TafsirText(
        _text,
        style: AppTextStyles.bodyStrong,
        color: AppColors.paper.inkMuted,
      ),
    );
    final style = tester.widget<Text>(find.byType(Text)).style!;
    expect(style.fontSize, AppTextStyles.bodyStrong.fontSize);
    expect(style.color, AppColors.paper.inkMuted);
  });

  testWidgets('wraps at 200% text scale without overflow', (tester) async {
    tester.view
      ..physicalSize = const Size(360, 640)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      goldenApp(
        ReadingTheme.paper,
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: const TafsirText(_text),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  test('an inline span carries the text whole in its own style', () {
    final style = AppTextStyles.caption.copyWith(inherit: false);
    final span = TafsirText.span(_text, style: style);
    expect(span.text, _value);
    expect(span.style, style);
  });
}
