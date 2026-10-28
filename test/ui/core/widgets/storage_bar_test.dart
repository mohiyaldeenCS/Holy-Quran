import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/widgets/progress_bar.dart';
import 'package:holyquran/ui/core/widgets/storage_bar.dart';

import '../../../../testing/golden.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  goldenApp(ReadingTheme.paper, SizedBox(width: 300, child: child)),
);

double _fill(WidgetTester tester) => tester
    .widget<FractionallySizedBox>(find.byType(FractionallySizedBox))
    .widthFactor!;

void main() {
  testWidgets('fills by the share of the whole', (tester) async {
    await _pump(
      tester,
      StorageBar(
        label: _l10n.resourceCategoryTafsirs,
        usedBytes: 250,
        totalBytes: 1000,
      ),
    );
    expect(tester.widget<ProgressBar>(find.byType(ProgressBar)).value, 0.25);
    expect(_fill(tester), 0.25);
  });

  testWidgets('reads its category and share in Arabic-Indic digits', (
    tester,
  ) async {
    await _pump(
      tester,
      StorageBar(
        label: _l10n.resourceCategoryTafsirs,
        usedBytes: 250,
        totalBytes: 1000,
      ),
    );
    expect(
      tester.getSemantics(find.byType(ProgressBar)),
      matchesSemantics(label: _l10n.resourceCategoryTafsirs, value: '٢٥٪'),
    );
  });

  testWidgets('a whole of nothing draws an empty track', (tester) async {
    await _pump(
      tester,
      StorageBar(
        label: _l10n.resourceCategoryTafsirs,
        usedBytes: 0,
        totalBytes: 0,
      ),
    );
    expect(_fill(tester), 0);
  });

  testWidgets('the shares of the categories and the free space add up', (
    tester,
  ) async {
    const used = [300, 200, 0];
    const free = 500;
    final total = used.fold(free, (sum, bytes) => sum + bytes);
    await _pump(
      tester,
      Column(
        children: [
          for (final bytes in used)
            StorageBar(
              label: _l10n.resourceCategoryTafsirs,
              usedBytes: bytes,
              totalBytes: total,
            ),
        ],
      ),
    );
    final shares = [
      for (final bar in tester.widgetList<ProgressBar>(
        find.byType(ProgressBar),
      ))
        bar.value,
    ];
    expect(shares, [0.3, 0.2, 0]);
    expect(shares.fold(free / total, (sum, share) => sum + share), 1);
  });

  testWidgets('fills from the right', (tester) async {
    await _pump(
      tester,
      StorageBar(
        label: _l10n.resourceCategoryTafsirs,
        usedBytes: 250,
        totalBytes: 1000,
      ),
    );
    final track = tester.getRect(find.byType(ProgressBar));
    final fill = tester.getRect(
      find.descendant(
        of: find.byType(FractionallySizedBox),
        matching: find.byType(DecoratedBox),
      ),
    );
    expect(fill.right, track.right);
    expect(fill.width, closeTo(track.width / 4, 0.01));
  });

  testWidgets('a used share, a small one and none', tags: ['golden'], (
    tester,
  ) async {
    await expectGoldensInThemes(
      tester,
      'storage_bar',
      (context) => SizedBox(
        width: 340,
        child: goldenColumn([
          for (final used in [600, 40, 0])
            StorageBar(
              label: _l10n.resourceCategoryTafsirs,
              usedBytes: used,
              totalBytes: 1000,
            ),
        ]),
      ),
      surfaceSize: const Size(400, 160),
    );
  });
}
