import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/data/repositories/reading_position_repository.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/continue_card.dart';
import 'package:holyquran/ui/core/widgets/home_door.dart';
import 'package:holyquran/ui/core/widgets/home_header.dart';
import 'package:holyquran/ui/core/widgets/progress_bar.dart';
import 'package:holyquran/ui/features/home/views/home_screen.dart';
import 'package:provider/provider.dart';

import '../home_harness.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

final _positionLine = _l10n.readingPositionLine(
  arabicDigits(3),
  arabicDigits(3),
  arabicDigits(2),
);

void main() {
  testWidgets('on first run shows the greeting and the door, and no card', (
    tester,
  ) async {
    await pumpHome(tester);

    expect(find.byType(HomeHeader), findsOneWidget);
    expect(find.text(_l10n.homeGreeting), findsOneWidget);
    expect(find.text(_l10n.homeContinueHint), findsOneWidget);
    expect(find.byType(ContinueCard), findsNothing);
    expect(find.byType(HomeDoor), findsOneWidget);
    expect(find.text(_l10n.homeDoorIndex), findsOneWidget);
    expect(find.text(_l10n.homeDoorBookmarks), findsNothing);
    expect(find.text(_l10n.continueListeningLabel), findsNothing);
  });

  testWidgets('shows no card without a verified pack', (tester) async {
    await pumpHome(tester, last: syntheticAyah(), withIndex: false);

    expect(find.byType(ContinueCard), findsNothing);
  });

  testWidgets('with a position, the card shows where and how far', (
    tester,
  ) async {
    await pumpHome(tester, last: syntheticAyah());

    expect(find.byType(ContinueCard), findsOneWidget);
    expect(find.text(_positionLine), findsOneWidget);
    expect(tester.widget<ProgressBar>(find.byType(ProgressBar)).value, 3 / 4);
  });

  testWidgets('the card appears when a position is saved', (tester) async {
    await pumpHome(tester);
    final positions = tester
        .element(find.byType(HomeScreen))
        .read<ReadingPositionRepository>();

    await positions.save(syntheticAyah());
    await tester.pump();

    expect(find.text(_positionLine), findsOneWidget);
  });

  testWidgets('the card continues at the position', (tester) async {
    final router = await pumpHome(tester, last: syntheticAyah());

    await tester.tap(find.text(_l10n.continueReadingAction));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, Routes.mushafRead(syntheticAyah()));
  });

  testWidgets('the index door opens the index', (tester) async {
    final router = await pumpHome(tester);

    await tester.tap(find.byType(HomeDoor));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, Routes.mushafIndex);
  });

  testWidgets('the search button opens search', (tester) async {
    final router = await pumpHome(tester);

    await tester.tap(find.bySemanticsLabel(_l10n.homeSearch));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, Routes.search);
  });

  testWidgets('the order is greeting, card, doors, right to left', (
    tester,
  ) async {
    await pumpHome(tester, last: syntheticAyah());

    final hint = tester.getRect(find.text(_l10n.homeContinueHint));
    final card = tester.getRect(find.byType(ContinueCard));
    final door = tester.getRect(find.byType(HomeDoor));
    final screen = tester.getRect(find.byType(HomeScreen));
    expect(hint.bottom, lessThan(card.top));
    expect(card.bottom, lessThan(door.top));
    expect(hint.right, card.right);
    // The door takes the first of four columns, at the start.
    expect(door.right, card.right);
    expect(door.width, lessThan(card.width / 4));
    expect(hint.right, lessThan(screen.right));
  });

  testWidgets('the greeting is 14 at 400 in ink-muted, at its own height', (
    tester,
  ) async {
    await pumpHome(tester);

    final greeting = tester.widget<RichText>(
      find.descendant(
        of: find.text(_l10n.homeGreeting),
        matching: find.byType(RichText),
      ),
    );
    final style = greeting.text.style!;
    expect(style.fontSize, 14);
    expect(style.fontWeight, FontWeight.w400);
    expect(style.height, isNull);
    expect(style.color, AppColors.paper.inkMuted);
    final heading = tester.widget<RichText>(
      find.descendant(
        of: find.text(_l10n.homeContinueHint),
        matching: find.byType(RichText),
      ),
    );
    expect(heading.text.style!.fontSize, AppTextStyles.screenTitle.fontSize);
    expect(heading.text.style!.height, AppTextStyles.screenTitle.height);
    expect(heading.text.style!.color, AppColors.paper.ink);
  });

  testWidgets('the heading is a header and every target is labelled', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpHome(tester, last: syntheticAyah());

    expect(
      tester.getSemantics(find.text(_l10n.homeContinueHint)),
      matchesSemantics(label: _l10n.homeContinueHint, isHeader: true),
    );
    expect(find.bySemanticsLabel(_l10n.homeDoorIndex), findsOneWidget);
    expect(find.bySemanticsLabel(_l10n.continueReadingAction), findsOneWidget);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  for (final theme in ReadingTheme.values) {
    testWidgets('lays out without overflow in ${theme.name} at 200%', (
      tester,
    ) async {
      await pumpHome(
        tester,
        last: syntheticAyah(),
        theme: theme,
        textScale: 2,
        size: const Size(360, 640),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(ContinueCard), findsOneWidget);
      await tester.scrollUntilVisible(find.byType(HomeDoor), 100);
      await tester.tap(find.byType(HomeDoor));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
