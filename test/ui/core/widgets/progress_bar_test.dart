import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/theme/ramps.g.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/progress_bar.dart';

import '../../../../testing/golden.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));
const _width = 300.0;

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
          child: SizedBox(width: _width, child: child),
        ),
      ),
    ),
  );
}

Finder _boxes() => find.descendant(
  of: find.byType(ProgressBar),
  matching: find.byType(DecoratedBox),
);

BoxDecoration _track(WidgetTester tester) =>
    tester.widget<DecoratedBox>(_boxes().first).decoration as BoxDecoration;

BoxDecoration _fill(WidgetTester tester) =>
    tester.widget<DecoratedBox>(_boxes().last).decoration as BoxDecoration;

void main() {
  testWidgets('is 6 high by default, radius 3, the height given otherwise', (
    tester,
  ) async {
    await _pump(tester, ProgressBar(value: 0.5, label: _l10n.playerPosition));
    expect(tester.getSize(find.byType(ProgressBar)), const Size(_width, 6));
    const radius = BorderRadius.all(Radius.circular(3));
    expect(
      tester.widget<ClipRRect>(find.byType(ClipRRect)).borderRadius,
      radius,
    );
    expect(_fill(tester).borderRadius, radius);

    await _pump(
      tester,
      ProgressBar(value: 0.5, label: _l10n.playerPosition, height: 8),
    );
    expect(tester.getSize(find.byType(ProgressBar)).height, 8);
  });

  testWidgets('colours each tone as the reference does', (tester) async {
    const colors = AppColors.paper;
    final expected = {
      ProgressBarTone.primary: (colors.line, colors.primary),
      ProgressBarTone.player: (
        Ramps.paper100.withValues(alpha: 0.22),
        colors.playerAccent,
      ),
    };
    for (final MapEntry(key: tone, value: (track, fill)) in expected.entries) {
      await _pump(
        tester,
        ProgressBar(value: 0.5, label: _l10n.playerPosition, tone: tone),
      );
      expect(_track(tester).color, track, reason: tone.name);
      expect(_fill(tester).color, fill, reason: tone.name);
    }
  });

  testWidgets('fills from the right in right-to-left', (tester) async {
    await _pump(tester, ProgressBar(value: 0.4, label: _l10n.playerPosition));
    final track = tester.getRect(find.byType(ProgressBar));
    final fill = tester.getRect(_boxes().last);
    expect(fill.right, track.right);
    expect(fill.width, closeTo(_width * 0.4, 0.001));
    expect(fill.height, track.height);
  });

  testWidgets('clamps the value between 0 and 1', (tester) async {
    for (final (value, width) in [(-0.5, 0.0), (1.7, _width)]) {
      await _pump(
        tester,
        ProgressBar(value: value, label: _l10n.playerPosition),
      );
      expect(tester.getSize(_boxes().last).width, width, reason: '$value');
    }
  });

  testWidgets('reads its label and the percentage in Arabic-Indic digits', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, ProgressBar(value: 0.456, label: _l10n.playerPosition));
    expect(
      tester.getSemantics(find.byType(ProgressBar)),
      matchesSemantics(
        label: _l10n.playerPosition,
        value: _l10n.percentValue(arabicDigits(46)),
      ),
    );
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('takes no focus', (tester) async {
    await _pump(tester, ProgressBar(value: 0.5, label: _l10n.playerPosition));
    expect(
      find.descendant(
        of: find.byType(ProgressBar),
        matching: find.byType(Focus),
      ),
      findsNothing,
    );
  });

  testWidgets('does not overflow at 200% text on 360 wide', (tester) async {
    await _pump(
      tester,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final tone in ProgressBarTone.values)
            ProgressBar(value: 0.7, label: _l10n.playerPosition, tone: tone),
        ],
      ),
      textScale: 2,
    );
    expect(tester.takeException(), isNull);
  });
}
