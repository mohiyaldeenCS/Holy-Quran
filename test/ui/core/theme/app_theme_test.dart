import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/ui/core/theme/app_theme.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';

void main() {
  const brightness = {
    ReadingTheme.paper: Brightness.light,
    ReadingTheme.night: Brightness.dark,
    ReadingTheme.sepia: Brightness.light,
    ReadingTheme.contrast: Brightness.dark,
  };

  for (final theme in ReadingTheme.values) {
    group(theme.name, () {
      final data = buildAppTheme(theme);
      final colors = AppColors.byId[theme.name]!;

      test('is built once', () {
        expect(identical(buildAppTheme(theme), data), isTrue);
      });

      test('has the theme brightness', () {
        expect(data.brightness, brightness[theme]);
        expect(data.colorScheme.brightness, brightness[theme]);
      });

      test('carries the generated colour and shadow instances', () {
        expect(data.extension<AppColors>(), same(colors));
        expect(data.extension<AppShadows>(), same(AppShadows.byId[theme.name]));
      });

      test('maps the colour scheme by role', () {
        final scheme = data.colorScheme;
        expect(scheme.primary, colors.primary);
        expect(scheme.onPrimary, colors.onPrimary);
        expect(scheme.primaryContainer, colors.primarySoft);
        expect(scheme.onPrimaryContainer, colors.onPrimarySoft);
        expect(scheme.secondary, colors.accent);
        expect(scheme.error, colors.error);
        expect(scheme.surface, colors.surface);
        expect(scheme.onSurface, colors.ink);
        expect(scheme.onSurfaceVariant, colors.inkMuted);
        expect(scheme.outline, colors.lineStrong);
        expect(scheme.outlineVariant, colors.line);
        expect(scheme.scrim, colors.scrim);
        expect(scheme.shadow.a, 0);
        expect(scheme.surfaceTint.a, 0);
      });

      test('paints the scaffold in ground', () {
        expect(data.scaffoldBackgroundColor, colors.ground);
        expect(data.canvasColor, colors.ground);
      });

      test('writes default text as body in ink', () {
        final body = data.textTheme.bodyMedium!;
        expect(body.fontFamily, AppFonts.sans);
        expect(body.fontSize, AppTextStyles.body.fontSize);
        expect(body.height, AppTextStyles.body.height);
        expect(body.fontWeight, AppTextStyles.body.fontWeight);
        expect(body.letterSpacing, AppTextStyles.body.letterSpacing);
        expect(body.leadingDistribution, TextLeadingDistribution.even);
        expect(body.color, colors.ink);
      });

      test('letter-spaces no text style', () {
        for (final (name, textTheme) in [
          ('textTheme', data.textTheme),
          ('primaryTextTheme', data.primaryTextTheme),
        ]) {
          final slots = _slots(textTheme);
          expect(slots, hasLength(15));
          for (final MapEntry(key: slot, value: style) in slots.entries) {
            expect(style?.letterSpacing, 0, reason: '$name.$slot');
          }
        }
      });

      test('keeps the identity font and colours in every slot', () {
        for (final MapEntry(key: slot, value: style) in _slots(
          data.textTheme,
        ).entries) {
          expect(style?.fontFamily, AppFonts.sans, reason: slot);
          expect(style?.color, colors.ink, reason: slot);
        }
        for (final MapEntry(key: slot, value: style) in _slots(
          data.primaryTextTheme,
        ).entries) {
          expect(style?.fontFamily, AppFonts.sans, reason: slot);
          expect(style?.color, colors.onPrimary, reason: slot);
        }
      });

      test('selects text in selection with a primary cursor', () {
        expect(data.textSelectionTheme.selectionColor, colors.selection);
        expect(data.textSelectionTheme.cursorColor, colors.primary);
        expect(data.textSelectionTheme.selectionHandleColor, colors.primary);
      });

      test('has no ripple, highlight, hover or focus fill', () {
        expect(data.splashFactory, same(NoSplash.splashFactory));
        expect(data.splashColor.a, 0);
        expect(data.highlightColor.a, 0);
        expect(data.hoverColor.a, 0);
        expect(data.focusColor.a, 0);
        expect(data.shadowColor.a, 0);
      });

      testWidgets('draws no ripple when a control is pressed', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: data,
            home: Material(
              child: Center(
                child: InkWell(
                  onTap: () {},
                  child: const SizedBox.square(dimension: AppSizes.targetMin),
                ),
              ),
            ),
          ),
        );
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(InkWell)),
        );
        await tester.pump(const Duration(milliseconds: 100));

        final inkFeatures = tester.allRenderObjects.firstWhere(
          (object) => object.runtimeType.toString() == '_RenderInkFeatures',
        );
        expect(
          inkFeatures,
          paints..everything(
            (method, arguments) => !arguments.any(
              (argument) =>
                  argument is Paint &&
                  (argument.color.a > 0 || argument.shader != null),
            ),
          ),
        );
        await gesture.up();
      });

      testWidgets('is reachable from a build context', (tester) async {
        late BuildContext context;
        await tester.pumpWidget(
          Theme(
            data: data,
            child: Builder(
              builder: (c) {
                context = c;
                return const SizedBox();
              },
            ),
          ),
        );
        expect(context.colors, same(colors));
        // Theme.of merges Material's text geometry underneath; it must not
        // bring letter spacing back.
        final localized = Theme.of(context);
        for (final textTheme in [
          localized.textTheme,
          localized.primaryTextTheme,
        ]) {
          for (final MapEntry(key: slot, value: style) in _slots(
            textTheme,
          ).entries) {
            expect(style?.letterSpacing, 0, reason: slot);
          }
        }
        expect(context.shadows, same(AppShadows.byId[theme.name]));
      });
    });
  }

  testWidgets('a theme without the tokens fails clearly', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      Theme(
        data: ThemeData(),
        child: Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(() => context.colors, throwsStateError);
    expect(() => context.shadows, throwsStateError);
  });
}

Map<String, TextStyle?> _slots(TextTheme t) => {
  'displayLarge': t.displayLarge,
  'displayMedium': t.displayMedium,
  'displaySmall': t.displaySmall,
  'headlineLarge': t.headlineLarge,
  'headlineMedium': t.headlineMedium,
  'headlineSmall': t.headlineSmall,
  'titleLarge': t.titleLarge,
  'titleMedium': t.titleMedium,
  'titleSmall': t.titleSmall,
  'bodyLarge': t.bodyLarge,
  'bodyMedium': t.bodyMedium,
  'bodySmall': t.bodySmall,
  'labelLarge': t.labelLarge,
  'labelMedium': t.labelMedium,
  'labelSmall': t.labelSmall,
};
