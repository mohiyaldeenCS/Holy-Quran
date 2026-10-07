import 'package:flutter/material.dart' hide Icon, IconButton;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/icon.dart';
import 'package:holyquran/ui/core/widgets/icon_button.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';

import '../../../../testing/golden.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double textScale = 1,
}) async {
  tester.view
    ..physicalSize = const Size(360, 800)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    goldenApp(
      ReadingTheme.paper,
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

Finder _face() => find.descendant(
  of: find.byType(IconButton),
  matching: find.byWidgetPredicate(
    (w) => w is Container && w.decoration != null,
  ),
);

void main() {
  testWidgets('is a 48 circle with a 24 icon by default', (tester) async {
    await _pump(
      tester,
      IconButton(icon: IconName.search, label: _l10n.tabHome, onPressed: () {}),
    );
    expect(tester.getSize(find.byType(IconButton)), const Size.square(48));
    expect(tester.getSize(_face()), const Size.square(48));
    expect(tester.widget<Icon>(find.byType(Icon)).size, AppSizes.iconSize);
    final decoration =
        tester.widget<Container>(_face()).decoration! as BoxDecoration;
    expect(
      decoration.borderRadius,
      BorderRadius.circular(AppRadius.radiusFull),
    );
  });

  testWidgets('colours each tone as the reference does', (tester) async {
    const colors = AppColors.paper;
    final expected = {
      IconButtonTone.plain: (null, colors.primary),
      IconButtonTone.tint: (colors.surfaceSunk, colors.primary),
      IconButtonTone.solid: (colors.primary, colors.onPrimary),
    };
    for (final MapEntry(key: tone, value: (bg, fg)) in expected.entries) {
      await _pump(
        tester,
        IconButton(
          icon: IconName.bookmark,
          label: _l10n.tabHome,
          onPressed: () {},
          tone: tone,
        ),
      );
      final decoration =
          tester.widget<Container>(_face()).decoration! as BoxDecoration;
      expect(decoration.color, bg, reason: tone.name);
      expect(tester.widget<Icon>(find.byType(Icon)).color, fg);
    }
  });

  testWidgets('keeps a 48 hit area when drawn smaller', (tester) async {
    var presses = 0;
    await _pump(
      tester,
      IconButton(
        icon: IconName.close,
        label: _l10n.tabHome,
        onPressed: () => presses++,
        size: 32,
        iconSize: 20,
      ),
    );
    expect(tester.getSize(_face()), const Size.square(32));
    expect(tester.getSize(find.byType(IconButton)), const Size.square(48));
    expect(tester.widget<Icon>(find.byType(Icon)).size, 20);
    final corner = tester.getTopLeft(find.byType(IconButton));
    await tester.tapAt(corner + const Offset(2, 2));
    expect(presses, 1);
  });

  testWidgets('calls onPressed when tapped or activated by keyboard', (
    tester,
  ) async {
    var presses = 0;
    await _pump(
      tester,
      IconButton(
        icon: IconName.play,
        label: _l10n.tabListen,
        onPressed: () => presses++,
      ),
    );
    await tester.tap(find.byType(IconButton));
    expect(presses, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(presses, 2);
  });

  testWidgets('reads as a button named by its label', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: IconName.search,
            label: _l10n.tabHome,
            onPressed: () {},
          ),
          IconButton(
            icon: IconName.more,
            label: _l10n.tabMore,
            onPressed: () {},
            size: 32,
          ),
        ],
      ),
    );
    expect(
      tester.getSemantics(find.byType(IconButton).first),
      matchesSemantics(
        label: _l10n.tabHome,
        isButton: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    expect(find.byTooltip(_l10n.tabHome), findsNothing);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('does not overflow at 200% text on 360 wide', (tester) async {
    await _pump(
      tester,
      Wrap(
        children: [
          for (final tone in IconButtonTone.values)
            IconButton(
              icon: IconName.settings,
              label: _l10n.tabMore,
              onPressed: () {},
              tone: tone,
            ),
        ],
      ),
      textScale: 2,
    );
    expect(tester.takeException(), isNull);
  });
}
