import 'package:flutter/material.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/icon.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/core/widgets/integrity_alert.dart';
import 'package:holyquran/ui/core/widgets/unapproved_copy_banner.dart';

import '../../../../testing/golden.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

Future<void> _pump(
  WidgetTester tester, {
  ReadingTheme theme = ReadingTheme.paper,
  double textScale = 1,
  double width = 320,
  double statusBar = 0,
}) async {
  tester.view
    ..physicalSize = Size(width, 600)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    goldenApp(
      theme,
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            padding: EdgeInsets.only(top: statusBar),
          ),
          // Loose, bounded 320 x 600: the banner must not grow to fill it.
          child: const Align(
            alignment: Alignment.topCenter,
            child: SizedBox(width: 320, child: UnapprovedCopyBanner()),
          ),
        ),
      ),
    ),
  );
}

BoxDecoration _decoration(WidgetTester tester) =>
    tester
            .widget<DecoratedBox>(
              find.descendant(
                of: find.byType(UnapprovedCopyBanner),
                matching: find.byType(DecoratedBox),
              ),
            )
            .decoration
        as BoxDecoration;

void main() {
  testWidgets('is an alert titled with the approved wording, in error', (
    tester,
  ) async {
    await _pump(tester);
    const colors = AppColors.paper;
    final alert = tester.widget<IntegrityAlert>(find.byType(IntegrityAlert));
    expect(alert.title, _l10n.unapprovedTestCopy);
    expect(alert.body, isNull);
    expect(alert.action, isNull);
    expect(tester.widget<Icon>(find.byType(Icon)).name, IconName.alert);
    final text = tester.widget<Text>(find.text(_l10n.unapprovedTestCopy));
    expect(text.style?.color, colors.error);
    expect(text.style?.decoration, isNot(TextDecoration.underline));
  });

  testWidgets('reads as one container with the wording as its label', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);
    expect(find.bySemanticsLabel(_l10n.unapprovedTestCopy), findsOneWidget);
    expect(tester.widget<Icon>(find.byType(Icon)).semanticLabel, isNull);
    handle.dispose();
  });

  for (final theme in ReadingTheme.values) {
    testWidgets('sits on surface under a line hairline in ${theme.name}', (
      tester,
    ) async {
      await _pump(tester, theme: theme);
      final colors = AppColors.byId[theme.name]!;
      final decoration = _decoration(tester);
      expect(decoration.color, colors.surface);
      final border = decoration.border! as Border;
      expect(border.bottom.color, colors.line);
      expect(border.bottom.width, 1);
      expect(border.top, BorderSide.none);
      expect(
        tester.widget<Text>(find.text(_l10n.unapprovedTestCopy)).style?.color,
        colors.error,
      );
    });

    testWidgets('lays out at 200% text on 320 wide in ${theme.name}', (
      tester,
    ) async {
      await _pump(tester, theme: theme, textScale: 2);
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(UnapprovedCopyBanner)).width, 320);
    });
  }

  testWidgets('pads space-4 across and space-2 down', (tester) async {
    await _pump(tester);
    final banner = tester.getRect(find.byType(UnapprovedCopyBanner));
    final alert = tester.getRect(find.byType(IntegrityAlert));
    expect(alert.left - banner.left, AppSpacing.space4);
    expect(banner.right - alert.right, AppSpacing.space4);
    expect(alert.top - banner.top, AppSpacing.space2);
    expect(banner.bottom - alert.bottom, AppSpacing.space2 + 1);
  });

  double contentHeight(WidgetTester tester) {
    final icon = tester.getSize(find.byType(Icon)).height;
    final text = tester.getSize(find.text(_l10n.unapprovedTestCopy)).height;
    return icon > text ? icon : text;
  }

  testWidgets('is as tall as its content, padding and hairline', (
    tester,
  ) async {
    await _pump(tester);
    expect(
      tester.getSize(find.byType(UnapprovedCopyBanner)).height,
      contentHeight(tester) + AppSpacing.space2 * 2 + 1,
    );
    expect(
      tester.getSize(find.byType(UnapprovedCopyBanner)).height,
      lessThan(120),
    );
  });

  testWidgets('at 200% text on 320 wide the title wraps and grows the strip', (
    tester,
  ) async {
    await _pump(tester);
    final normal = tester.getSize(find.byType(UnapprovedCopyBanner)).height;
    final normalText = tester.getSize(find.text(_l10n.unapprovedTestCopy));
    await _pump(tester, textScale: 2);
    expect(tester.takeException(), isNull);
    final text = tester.getSize(find.text(_l10n.unapprovedTestCopy));
    expect(text.height, greaterThan(normalText.height * 2));
    final banner = tester.getSize(find.byType(UnapprovedCopyBanner)).height;
    expect(banner, greaterThan(normal));
    expect(banner, contentHeight(tester) + AppSpacing.space2 * 2 + 1);
    final bannerRect = tester.getRect(find.byType(UnapprovedCopyBanner));
    final textRect = tester.getRect(find.text(_l10n.unapprovedTestCopy));
    expect(bannerRect.contains(textRect.topLeft), isTrue);
    expect(bannerRect.bottom - textRect.bottom, AppSpacing.space2 + 1);
    expect(textRect.left, greaterThanOrEqualTo(bannerRect.left));
    expect(textRect.right, lessThanOrEqualTo(bannerRect.right));
  });

  testWidgets('keeps clear of the status bar and draws under it', (
    tester,
  ) async {
    await _pump(tester, statusBar: 24);
    final banner = tester.getRect(find.byType(UnapprovedCopyBanner));
    final alert = tester.getRect(find.byType(IntegrityAlert));
    expect(banner.top, 0);
    expect(alert.top - banner.top, 24 + AppSpacing.space2);
  });

  testWidgets('does not take the bottom inset', (tester) async {
    await _pump(tester);
    final before = tester.getSize(find.byType(UnapprovedCopyBanner)).height;
    tester.view.padding = const FakeViewPadding(bottom: 34);
    await tester.pump();
    expect(tester.getSize(find.byType(UnapprovedCopyBanner)).height, before);
  });

  testWidgets('the strip, in each theme', tags: ['golden'], (tester) async {
    await expectGoldensInThemes(
      tester,
      'unapproved_copy_banner',
      (context) => const SizedBox(width: 360, child: UnapprovedCopyBanner()),
      surfaceSize: const Size(400, 120),
    );
  });
}
