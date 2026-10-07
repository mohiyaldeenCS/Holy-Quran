import 'package:flutter/material.dart' hide Icon;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/ramps.g.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/button.dart';
import 'package:holyquran/ui/core/widgets/icon.dart';
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

BoxDecoration _decoration(WidgetTester tester) =>
    tester
            .widget<DecoratedBox>(
              find.descendant(
                of: find.byType(Button),
                matching: find.byType(DecoratedBox),
              ),
            )
            .decoration
        as BoxDecoration;

Text _text(WidgetTester tester) => tester.widget<Text>(
  find.descendant(of: find.byType(Button), matching: find.byType(Text)),
);

void main() {
  testWidgets('is 52 high, radius 16, 17 px semibold', (tester) async {
    await _pump(tester, Button(label: _l10n.tabHome, onPressed: () {}));
    expect(tester.getSize(find.byType(Button)).height, AppSizes.buttonHeight);
    expect(
      _decoration(tester).borderRadius,
      BorderRadius.circular(AppRadius.radiusButton),
    );
    final style = _text(tester).style!;
    expect(style.fontSize, AppTextStyles.bodyStrong.fontSize);
    expect(style.fontWeight, FontWeight.w600);
  });

  testWidgets('colours each variant as the reference does', (tester) async {
    const colors = AppColors.paper;
    final expected = {
      ButtonVariant.primary: (colors.primary, colors.onPrimary, null),
      ButtonVariant.outline: (null, colors.primary, colors.primary),
      ButtonVariant.tonal: (Ramps.gold100, Ramps.goldTextStrong, null),
      ButtonVariant.text: (null, colors.primary, null),
    };
    for (final MapEntry(key: variant, value: (bg, fg, ring))
        in expected.entries) {
      await _pump(
        tester,
        Button(label: _l10n.tabHome, onPressed: () {}, variant: variant),
      );
      final decoration = _decoration(tester);
      expect(decoration.color, bg, reason: variant.name);
      expect(_text(tester).style!.color, fg, reason: variant.name);
      final border = decoration.border as Border?;
      expect(border?.top.color, ring, reason: variant.name);
      if (ring != null) expect(border!.top.width, 1.5);
    }
  });

  testWidgets('pads 24 on each side, 16 for the text variant', (tester) async {
    for (final (variant, padding) in [
      (ButtonVariant.primary, AppSpacing.space5),
      (ButtonVariant.text, AppSpacing.space4),
    ]) {
      await _pump(
        tester,
        Button(label: _l10n.tabHome, onPressed: () {}, variant: variant),
      );
      final button = tester.getRect(find.byType(Button));
      final text = tester.getRect(find.byType(Text));
      expect(button.right - text.right, padding, reason: variant.name);
      expect(text.left - button.left, padding, reason: variant.name);
    }
  });

  testWidgets('puts a 22 px icon before the label, at the right', (
    tester,
  ) async {
    await _pump(
      tester,
      Button(label: _l10n.tabListen, onPressed: () {}, icon: IconName.play),
    );
    final icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.size, 22);
    expect(icon.color, AppColors.paper.onPrimary);
    final iconRect = tester.getRect(find.byType(Icon));
    final textRect = tester.getRect(find.byType(Text));
    expect(iconRect.left, greaterThan(textRect.right));
    expect(iconRect.left - textRect.right, AppSpacing.space2);
  });

  testWidgets('calls onPressed when tapped or activated by keyboard', (
    tester,
  ) async {
    var presses = 0;
    await _pump(
      tester,
      Button(label: _l10n.tabHome, onPressed: () => presses++),
    );
    await tester.tap(find.byType(Button));
    expect(presses, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(presses, 2);
  });

  testWidgets('disabled: does nothing, drawn on surface-sunk', (tester) async {
    await _pump(
      tester,
      Button(
        label: _l10n.tabHome,
        onPressed: null,
        variant: ButtonVariant.outline,
      ),
    );
    await tester.tap(find.byType(Button), warnIfMissed: false);
    final decoration = _decoration(tester);
    expect(decoration.color, AppColors.paper.surfaceSunk);
    expect(decoration.border, isNull);
    expect(_text(tester).style!.color, AppColors.paper.inkDisabled);
  });

  testWidgets('reads as a labelled button, enabled or not', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Button(label: _l10n.tabHome, onPressed: () {}, icon: IconName.home),
          Button(label: _l10n.tabMore, onPressed: null),
        ],
      ),
    );
    expect(
      tester.getSemantics(find.byType(Button).first),
      matchesSemantics(
        label: _l10n.tabHome,
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.byType(Button).last),
      matchesSemantics(
        label: _l10n.tabMore,
        isButton: true,
        hasEnabledState: true,
      ),
    );
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('grows instead of clipping at 200% text on 360 wide', (
    tester,
  ) async {
    await _pump(
      tester,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final variant in ButtonVariant.values)
            Button(
              label: '${_l10n.mainNavigationLabel} ${_l10n.appTitle}',
              onPressed: () {},
              variant: variant,
              icon: IconName.download,
            ),
        ],
      ),
      textScale: 2,
    );
    expect(tester.takeException(), isNull);
    for (final element in find.byType(Button).evaluate()) {
      final size = (element.renderObject! as RenderBox).size;
      expect(size.width, lessThanOrEqualTo(360));
      expect(size.height, greaterThan(AppSizes.buttonHeight));
    }
  });
}
