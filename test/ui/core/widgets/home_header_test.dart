import 'package:flutter/material.dart' hide Icon, IconButton;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/ramps.g.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/focus_ring.dart';
import 'package:holyquran/ui/core/widgets/home_header.dart';
import 'package:holyquran/ui/core/widgets/icon_button.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/core/widgets/mark.dart';

import '../../../../testing/golden.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  ReadingTheme theme = ReadingTheme.paper,
  double textScale = 1,
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
          child: child,
        ),
      ),
    ),
  );
}

BoxDecoration _tile(WidgetTester tester) =>
    tester
            .widget<Container>(
              find.descendant(
                of: find.byType(AppIconTile),
                matching: find.byType(Container),
              ),
            )
            .decoration!
        as BoxDecoration;

bool _ringDrawn(WidgetTester tester) =>
    tester
        .widget<CustomPaint>(
          find
              .descendant(
                of: find.byType(FocusRing),
                matching: find.byType(CustomPaint),
              )
              .first,
        )
        .foregroundPainter !=
    null;

void main() {
  testWidgets('draws the 40 px emerald tile holding the emerald mark', (
    tester,
  ) async {
    for (final theme in ReadingTheme.values) {
      await _pump(tester, HomeHeader(onSearch: () {}), theme: theme);
      expect(tester.getSize(find.byType(AppIconTile)), const Size(40, 40));
      final tile = _tile(tester);
      expect(tile.color, Ramps.emerald700, reason: theme.name);
      expect(tile.borderRadius, BorderRadius.circular(28 * 40 / 120));
      final mark = tester.widget<Mark>(find.byType(Mark));
      expect(mark.size, 40);
      expect(mark.variant, MarkVariant.emerald);
      expect(mark.decorative, isTrue);
    }
  });

  testWidgets('writes the app name in app-title, brand-ink, 10 from the tile', (
    tester,
  ) async {
    await _pump(tester, HomeHeader(onSearch: () {}));
    final title = tester.widget<Text>(find.text(_l10n.appTitle));
    expect(title.style!.fontFamily, AppFonts.kufi);
    expect(title.style!.fontSize, AppTextStyles.appTitle.fontSize);
    expect(title.style!.fontWeight, FontWeight.w700);
    expect(title.style!.color, AppColors.paper.brandInk);

    final tile = tester.getRect(find.byType(AppIconTile));
    final text = tester.getRect(find.text(_l10n.appTitle));
    expect(tile.left - text.right, greaterThanOrEqualTo(10));
  });

  testWidgets('puts the tile at the right and search at the left', (
    tester,
  ) async {
    await _pump(tester, HomeHeader(onSearch: () {}));
    final header = tester.getRect(find.byType(HomeHeader));
    expect(tester.getRect(find.byType(AppIconTile)).right, header.right);
    expect(tester.getRect(find.byType(IconButton)).left, header.left);
  });

  testWidgets('search is a 48 tint icon button that calls onSearch', (
    tester,
  ) async {
    var searches = 0;
    await _pump(tester, HomeHeader(onSearch: () => searches++));
    final button = tester.widget<IconButton>(find.byType(IconButton));
    expect(button.icon, IconName.search);
    expect(button.tone, IconButtonTone.tint);
    expect(button.size, AppSizes.targetMin);
    expect(button.label, _l10n.homeSearch);
    await tester.tap(find.byType(IconButton));
    expect(searches, 1);
  });

  testWidgets('hides search when there is no onSearch', (tester) async {
    await _pump(tester, const HomeHeader());
    expect(find.byType(IconButton), findsNothing);
    expect(find.byType(AppIconTile), findsOneWidget);
    expect(find.text(_l10n.appTitle), findsOneWidget);
  });

  testWidgets('reads the tile as the app icon and labels search', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, HomeHeader(onSearch: () {}));
    expect(
      tester.getSemantics(find.byType(AppIconTile)),
      matchesSemantics(label: _l10n.appIconLabel, isImage: true),
    );
    expect(find.bySemanticsLabel(_l10n.appTitle), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(IconButton)),
      matchesSemantics(
        label: _l10n.homeSearch,
        isButton: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    expect(find.bySemanticsLabel(_l10n.homeSearch), findsOneWidget);
    expect(tester.getSemantics(find.byType(IconButton)).hasChildren, isFalse);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('rings search in keyboard mode only', (tester) async {
    addTearDown(
      () => FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.automatic,
    );
    await _pump(tester, HomeHeader(onSearch: () {}));
    expect(_ringDrawn(tester), isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(_ringDrawn(tester), isTrue);

    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTouch;
    await tester.pump();
    expect(_ringDrawn(tester), isFalse);
  });

  testWidgets('fits 360 wide at 200% text', (tester) async {
    await _pump(tester, HomeHeader(onSearch: () {}), textScale: 2);
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(HomeHeader)).width, 360);
    expect(tester.getSize(find.byType(AppIconTile)), const Size(40, 40));
  });
}
