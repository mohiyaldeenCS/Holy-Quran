import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/position_bar.dart';
import 'package:holyquran/ui/core/widgets/surah_name.dart';

import '../../../../testing/golden.dart';

// A synthetic name.
const _name = PackText.fromPack('اسم تجريبي');

final _l10n = lookupAppLocalizations(const Locale('ar'));

Future<void> _pump(
  WidgetTester tester, {
  ReadingTheme theme = ReadingTheme.paper,
  double textScale = 1,
  PackText name = _name,
}) async {
  tester.view
    ..physicalSize = const Size(360, 800)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    goldenApp(
      theme,
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: SizedBox(
            width: 320,
            child: PositionBar(surahName: name, juz: 30, hizb: 60),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('draws the name in Reem Kufi 20/600 primary, through SurahName', (
    tester,
  ) async {
    await _pump(tester);

    final surahName = tester.widget<SurahName>(find.byType(SurahName));
    expect(identical(surahName.name, _name), isTrue);
    expect(surahName.format, SurahNameFormat.name);
    final text = tester.widget<Text>(
      find.descendant(of: find.byType(SurahName), matching: find.byType(Text)),
    );
    expect(text.style!.fontFamily, AppFonts.kufi);
    expect(text.style!.fontSize, 20);
    expect(text.style!.fontWeight, FontWeight.w600);
    expect(text.style!.color, AppColors.paper.primary);
  });

  testWidgets('draws the juz and hizb in Arabic-Indic digits, 13 ink-muted', (
    tester,
  ) async {
    await _pump(tester);

    final line = tester.widget<Text>(find.text(_l10n.juzHizbLine('٣٠', '٦٠')));
    expect(line.style!.fontSize, 13);
    expect(line.style!.fontFamily, AppFonts.sans);
    expect(line.style!.color, AppColors.paper.inkMuted);
  });

  testWidgets('puts the name at the start and the line at the other end', (
    tester,
  ) async {
    await _pump(tester);

    final name = tester.getRect(find.byType(SurahName));
    final line = tester.getRect(find.text(_l10n.juzHizbLine('٣٠', '٦٠')));
    expect(name.right, greaterThan(line.right));
    expect(name.right, 320 + (360 - 320) / 2);
    expect(line.left, (360 - 320) / 2);
  });

  testWidgets('takes its colours from every theme', (tester) async {
    const palettes = {
      ReadingTheme.paper: AppColors.paper,
      ReadingTheme.night: AppColors.night,
      ReadingTheme.sepia: AppColors.sepia,
      ReadingTheme.contrast: AppColors.contrast,
    };
    for (final MapEntry(key: theme, value: colors) in palettes.entries) {
      await _pump(tester, theme: theme);
      expect(
        tester
            .widget<Text>(
              find.descendant(
                of: find.byType(SurahName),
                matching: find.byType(Text),
              ),
            )
            .style!
            .color,
        colors.primary,
        reason: theme.name,
      );
      expect(
        tester
            .widget<Text>(find.text(_l10n.juzHizbLine('٣٠', '٦٠')))
            .style!
            .color,
        colors.inkMuted,
        reason: theme.name,
      );
    }
  });

  testWidgets('wraps a long name and fits the line at 200%', (tester) async {
    await _pump(
      tester,
      textScale: 2,
      name: const PackText.fromPack('اسم تجريبي طويل جدا لسورة تجريبية'),
    );

    expect(tester.takeException(), isNull);
    final name = tester.getRect(find.byType(SurahName));
    final line = tester.getRect(find.text(_l10n.juzHizbLine('٣٠', '٦٠')));
    expect(name.overlaps(line), isFalse);
  });
}
