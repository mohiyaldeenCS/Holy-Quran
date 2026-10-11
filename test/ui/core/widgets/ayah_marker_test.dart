import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/theme/ramps.g.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/ayah_marker.dart';

import '../../../../testing/golden.dart';

Future<void> _pump(WidgetTester tester, Widget child) =>
    tester.pumpWidget(goldenApp(ReadingTheme.paper, child));

Size _diameter(WidgetTester tester) => tester.getSize(find.byType(AyahMarker));

Text _digits(WidgetTester tester) => tester.widget<Text>(
  find.descendant(of: find.byType(AyahMarker), matching: find.byType(Text)),
);

BoxDecoration _ring(WidgetTester tester) =>
    tester
            .widget<Container>(
              find.descendant(
                of: find.byType(AyahMarker),
                matching: find.byType(Container),
              ),
            )
            .decoration!
        as BoxDecoration;

void _scaleText(WidgetTester tester, double factor) {
  tester.platformDispatcher.textScaleFactorTestValue = factor;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

void main() {
  testWidgets('is read as «الآية n» with Arabic-Indic digits', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, const AyahMarker(number: 5));

    final l10n = lookupAppLocalizations(const Locale('ar'));
    expect(l10n.ayahMarkerLabel(arabicDigits(5)), 'الآية ٥');
    expect(find.bySemanticsLabel('الآية ٥'), findsOneWidget);
    expect(find.bySemanticsLabel('٥'), findsNothing);
    handle.dispose();
  });

  testWidgets('shows the number in Arabic-Indic digits in accent', (
    tester,
  ) async {
    await _pump(tester, const AyahMarker(number: 255));

    final text = _digits(tester);
    expect(text.data, arabicDigits(255));
    expect(text.style!.color, AppColors.paper.accent);
    expect(text.style!.fontFamily, AppFonts.sans);
    expect(text.style!.fontWeight, FontWeight.w600);
    expect(text.style!.height, 1);
  });

  testWidgets('is a thin ornament ring, filled while its ayah plays', (
    tester,
  ) async {
    await _pump(tester, const AyahMarker(number: 7));
    var ring = _ring(tester);
    expect(ring.shape, BoxShape.circle);
    expect(ring.color, isNull);
    expect(
      ring.border,
      Border.all(color: AppColors.paper.ornament, width: 1.2),
    );

    await _pump(tester, const AyahMarker(number: 7, playing: true));
    ring = _ring(tester);
    expect(ring.color, AppColors.paper.ornament);
    expect(_digits(tester).style!.color, Ramps.emerald950);
  });

  testWidgets('takes a thicker ring when asked, as AyahRow does', (
    tester,
  ) async {
    await _pump(tester, const AyahMarker(number: 7, size: 36, ringWidth: 1.5));
    expect(
      _ring(tester).border,
      Border.all(color: AppColors.paper.ornament, width: 1.5),
    );
  });

  testWidgets('sizes its digits from the diameter', (tester) async {
    await _pump(tester, const AyahMarker(number: 42));
    expect(_diameter(tester), const Size.square(AppSizes.ayahMarker));
    expect(_digits(tester).style!.fontSize, AppSizes.ayahMarker * 0.46);

    await _pump(tester, const AyahMarker(number: 286, size: 36));
    expect(_diameter(tester), const Size.square(36));
    expect(_digits(tester).style!.fontSize, 36 * 0.38);
  });

  testWidgets('scales the diameter with the text, the digits once', (
    tester,
  ) async {
    _scaleText(tester, 2);
    await _pump(tester, const AyahMarker(number: 5));

    expect(_diameter(tester), const Size.square(AppSizes.ayahMarker * 2));
    final text = _digits(tester);
    expect(text.style!.fontSize, AppSizes.ayahMarker * 2 * 0.46);
    expect(text.textScaler, TextScaler.noScaling);
  });

  testWidgets('does not overflow at 200% on a 360 wide screen', (tester) async {
    tester.view
      ..physicalSize = const Size(360, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    _scaleText(tester, 2);

    await _pump(
      tester,
      const Wrap(
        children: [
          AyahMarker(number: 5),
          AyahMarker(number: 255, playing: true),
          AyahMarker(number: 286, size: 36),
        ],
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
