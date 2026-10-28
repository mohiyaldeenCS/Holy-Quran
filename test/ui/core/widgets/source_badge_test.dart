import 'package:flutter/material.dart' hide Icon;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/icon.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/core/widgets/source_badge.dart';

import '../../../../testing/golden.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

// Synthetic, never a real book.
const _title = ' عنوان تجريبي  للكتاب ';
const _name = PackText.fromPack(_title);
const _version = 12;

Future<void> _pump(
  WidgetTester tester, {
  VoidCallback? onPressed,
  ReadingTheme theme = ReadingTheme.paper,
  double textScale = 1,
}) async {
  tester.view
    ..physicalSize = const Size(360, 640)
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
          child: SourceBadge(
            name: _name,
            version: _version,
            onPressed: onPressed ?? () {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows the name whole, then the version in Arabic-Indic '
      'digits', (tester) async {
    await _pump(tester);
    final text = tester.widget<RichText>(
      find.descendant(
        of: find.byType(SourceBadge),
        matching: find.byType(RichText),
      ),
    );
    expect(
      text.text.toPlainText(),
      '$_title${_l10n.dataSeparator}'
      '${_l10n.sourceVersion(arabicDigits(_version))}',
    );
    expect(find.byType(Icon), findsOneWidget);
    expect(tester.widget<Icon>(find.byType(Icon)).name, IconName.info);
  });

  testWidgets('draws in caption and accent', (tester) async {
    await _pump(tester);
    final text = tester.widget<RichText>(
      find.descendant(
        of: find.byType(SourceBadge),
        matching: find.byType(RichText),
      ),
    );
    // Text wraps the badge's span in one that holds the ambient style.
    final style = (text.text as TextSpan).children!.single.style!;
    expect(style.fontSize, AppTextStyles.caption.fontSize);
    expect(style.fontWeight, AppTextStyles.caption.fontWeight);
    expect(style.color, tester.element(find.byType(SourceBadge)).colors.accent);
  });

  testWidgets('is a button that opens the details, by tap and by key', (
    tester,
  ) async {
    var pressed = 0;
    await _pump(tester, onPressed: () => pressed++);
    await tester.tap(find.byType(SourceBadge));
    expect(pressed, 1);

    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(pressed, 2);
  });

  testWidgets('is one labelled button for a screen reader', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);
    final node = tester.getSemantics(find.byType(SourceBadge));
    expect(
      node,
      matchesSemantics(
        isButton: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
        label:
            '$_title${_l10n.dataSeparator}'
            '${_l10n.sourceVersion(arabicDigits(_version))}',
      ),
    );
    handle.dispose();
  });

  testWidgets('stands at least 48 high and wide', (tester) async {
    await _pump(tester);
    final size = tester.getSize(find.byType(SourceBadge));
    expect(size.height, greaterThanOrEqualTo(AppSizes.targetMin));
  });

  for (final theme in ReadingTheme.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('lays out without overflow in ${theme.name} at '
          '${(scale * 100).round()}%', (tester) async {
        await _pump(tester, theme: theme, textScale: scale);
        expect(tester.takeException(), isNull);
        expect(
          tester.getSize(find.byType(SourceBadge)).height,
          greaterThanOrEqualTo(AppSizes.targetMin),
        );
      });
    }
  }
}
