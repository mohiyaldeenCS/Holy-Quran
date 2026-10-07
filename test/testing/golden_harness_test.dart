import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/ui/core/theme/app_theme.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';

import '../../testing/golden.dart';

void main() {
  const root = ValueKey('root');
  const probe = ValueKey('probe');

  for (final theme in ReadingTheme.values) {
    group(theme.name, () {
      final colors = AppColors.byId[theme.name]!;

      Future<BuildContext> pumpProbe(WidgetTester tester) async {
        await tester.pumpWidget(
          goldenApp(theme, const SizedBox(key: probe), key: root),
        );
        return tester.element(find.byKey(probe));
      }

      testWidgets('carries the generated colours', (tester) async {
        final context = await pumpProbe(tester);
        expect(context.colors, same(colors));
        // Theme.of localises the text geometry for Arabic, so the instance
        // differs from buildAppTheme's; its colours do not.
        expect(Theme.of(context).colorScheme, buildAppTheme(theme).colorScheme);
      });

      testWidgets('lays out right to left', (tester) async {
        final context = await pumpProbe(tester);
        expect(Directionality.of(context), TextDirection.rtl);
      });

      testWidgets('paints the ground over the whole surface', (tester) async {
        await pumpProbe(tester);
        final ground = find.descendant(
          of: find.byKey(root),
          matching: find.byType(ColoredBox),
        );
        expect(tester.widget<ColoredBox>(ground.first).color, colors.ground);
        expect(
          tester.getSize(find.byKey(root)),
          tester.view.physicalSize / tester.view.devicePixelRatio,
        );
      });

      testWidgets('draws the root as its own layer', (tester) async {
        await pumpProbe(tester);
        expect(tester.renderObject(find.byKey(root)).isRepaintBoundary, isTrue);
      });

      testWidgets('centres the child', (tester) async {
        await pumpProbe(tester);
        expect(
          tester.getCenter(find.byKey(probe)),
          tester.getCenter(find.byKey(root)),
        );
      });

      testWidgets('sets text in the theme body style and ink', (tester) async {
        final context = await pumpProbe(tester);
        final style = DefaultTextStyle.of(context).style;
        expect(style, Theme.of(context).textTheme.bodyMedium);
        expect(style.color, colors.ink);
        expect(style.fontFamily, AppTextStyles.body.fontFamily);
        expect(style.fontSize, AppTextStyles.body.fontSize);
        expect(style.height, AppTextStyles.body.height);
      });
    });
  }

  testWidgets('goldenColumn stacks its children a space4 apart', (
    tester,
  ) async {
    const first = ValueKey('first');
    const second = ValueKey('second');
    await tester.pumpWidget(
      goldenApp(
        ReadingTheme.paper,
        goldenColumn(const [
          SizedBox(key: first, width: 10, height: 10),
          SizedBox(key: second, width: 10, height: 10),
        ]),
      ),
    );
    expect(
      tester.getTopLeft(find.byKey(second)).dy -
          tester.getBottomLeft(find.byKey(first)).dy,
      AppSpacing.space4,
    );
  });
}
