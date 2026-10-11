import 'package:flutter/material.dart' hide Icon;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/focus_ring.dart';
import 'package:holyquran/ui/core/widgets/home_door.dart';
import 'package:holyquran/ui/core/widgets/icon.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';

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

/// The home board's four-column row with the two Phase 1 doors first.
Widget _grid({VoidCallback? onIndex}) => Padding(
  padding: const EdgeInsets.symmetric(horizontal: 20),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: AppSpacing.space2,
    children: [
      Expanded(
        child: HomeDoor(
          icon: IconName.indexIcon,
          label: _l10n.homeDoorIndex,
          onPressed: onIndex ?? () {},
        ),
      ),
      Expanded(
        child: HomeDoor(
          icon: IconName.bookmark,
          label: _l10n.homeDoorBookmarks,
          onPressed: () {},
        ),
      ),
      const Spacer(),
      const Spacer(),
    ],
  ),
);

Finder _tile(String label) => find.descendant(
  of: find.widgetWithText(HomeDoor, label),
  matching: find.byType(Container),
);

bool _ringDrawn(WidgetTester tester) =>
    tester
        .widget<CustomPaint>(
          find
              .descendant(
                of: find.byType(FocusRing).first,
                matching: find.byType(CustomPaint),
              )
              .first,
        )
        .foregroundPainter !=
    null;

void main() {
  testWidgets('draws a 56 tile, radius 18, surface-sunk, 26 icon in primary', (
    tester,
  ) async {
    for (final theme in ReadingTheme.values) {
      final colors = AppColors.byId[theme.name]!;
      await _pump(tester, _grid(), theme: theme);
      final tile = _tile(_l10n.homeDoorIndex);
      expect(tester.getSize(tile), const Size(56, 56));
      final decoration =
          tester.widget<Container>(tile).decoration! as BoxDecoration;
      expect(decoration.color, colors.surfaceSunk, reason: theme.name);
      expect(decoration.borderRadius, BorderRadius.circular(18));
      final icon = tester.widget<Icon>(
        find.descendant(
          of: find.widgetWithText(HomeDoor, _l10n.homeDoorIndex),
          matching: find.byType(Icon),
        ),
      );
      expect(icon.name, IconName.indexIcon);
      expect(icon.size, 26);
      expect(icon.color, colors.primary, reason: theme.name);
    }
  });

  testWidgets('labels it 6 under the tile, 13 px 500 in ink', (tester) async {
    await _pump(tester, _grid());
    final label = tester.widget<Text>(find.text(_l10n.homeDoorIndex));
    expect(label.style!.fontSize, 13);
    expect(label.style!.fontWeight, FontWeight.w500);
    expect(label.style!.color, AppColors.paper.ink);
    expect(label.textAlign, TextAlign.center);
    expect(
      tester.getTopLeft(find.text(_l10n.homeDoorIndex)).dy -
          tester.getBottomLeft(_tile(_l10n.homeDoorIndex)).dy,
      6,
    );
  });

  testWidgets('starts the grid at the right, the index door first', (
    tester,
  ) async {
    await _pump(tester, _grid());
    final index = tester.getRect(
      find.widgetWithText(HomeDoor, _l10n.homeDoorIndex),
    );
    final bookmarks = tester.getRect(
      find.widgetWithText(HomeDoor, _l10n.homeDoorBookmarks),
    );
    expect(index.right, 340);
    expect(bookmarks.right, lessThan(index.left));
    expect(index.right - bookmarks.right, (320 - 3 * 8) / 4 + 8);
  });

  testWidgets('presses on a tap anywhere on the door and by keyboard', (
    tester,
  ) async {
    var presses = 0;
    await _pump(tester, _grid(onIndex: () => presses++));
    await tester.tap(_tile(_l10n.homeDoorIndex));
    await tester.tap(find.text(_l10n.homeDoorIndex));
    expect(presses, 2);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(presses, 3);
  });

  testWidgets('reads as one labelled button', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, _grid());
    expect(
      tester.getSemantics(find.widgetWithText(HomeDoor, _l10n.homeDoorIndex)),
      matchesSemantics(
        label: _l10n.homeDoorIndex,
        isButton: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    // One node: the label is not repeated elsewhere and has no child nodes.
    expect(find.bySemanticsLabel(_l10n.homeDoorIndex), findsOneWidget);
    expect(
      tester
          .getSemantics(find.widgetWithText(HomeDoor, _l10n.homeDoorIndex))
          .hasChildren,
      isFalse,
    );
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('rings the door in keyboard mode only', (tester) async {
    addTearDown(
      () => FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.automatic,
    );
    await _pump(tester, _grid());
    expect(_ringDrawn(tester), isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(_ringDrawn(tester), isTrue);
    expect(
      tester.widget<FocusRing>(find.byType(FocusRing).first).radius,
      BorderRadius.circular(18),
    );

    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTouch;
    await tester.pump();
    expect(_ringDrawn(tester), isFalse);
  });

  testWidgets('wraps its label without overflow at 200% on 360 wide', (
    tester,
  ) async {
    await _pump(tester, _grid(), textScale: 2);
    expect(tester.takeException(), isNull);
    expect(tester.getSize(_tile(_l10n.homeDoorIndex)), const Size(56, 56));
  });
}
