import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/gallery/gallery_section.dart';
import 'package:holyquran/ui/core/gallery/sections/resources_gallery.dart';
import 'package:holyquran/ui/core/widgets/integrity_alert.dart';
import 'package:holyquran/ui/core/widgets/storage_bar.dart';

import '../../../../testing/golden.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

Future<void> _pump(
  WidgetTester tester, {
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
          child: const SingleChildScrollView(child: ResourcesGallery()),
        ),
      ),
    ),
  );
}

void main() {
  for (final theme in ReadingTheme.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('lays out without overflow in ${theme.name} at '
          '${(scale * 100).round()}% on 360 wide', (tester) async {
        await _pump(tester, theme: theme, textScale: scale);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('titles its section with an existing key', (tester) async {
    await _pump(tester);
    expect(
      tester.widget<GallerySection>(find.byType(GallerySection)).title,
      _l10n.resourceManagerTitle,
    );
  });

  testWidgets('shows the storage bars and the alerts on sample words', (
    tester,
  ) async {
    await _pump(tester);
    final bars = tester.widgetList<StorageBar>(find.byType(StorageBar));
    expect(
      [for (final bar in bars) bar.label],
      [
        _l10n.resourceCategoryTafsirs,
        _l10n.resourceCategoryRiwayat,
        _l10n.resourceCategoryPageMushaf,
      ],
    );
    expect(find.byType(IntegrityAlert), findsNWidgets(3));
    expect(find.text(_l10n.sampleRowLabel), findsOneWidget);
    expect(find.text(_l10n.resourceRedownload), findsNWidgets(2));
    expect(find.text(_l10n.connectionFailed), findsOneWidget);
  });
}
