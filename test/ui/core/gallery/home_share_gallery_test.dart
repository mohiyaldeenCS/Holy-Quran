import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/gallery/gallery_section.dart';
import 'package:holyquran/ui/core/gallery/sections/home_share_gallery.dart';
import 'package:holyquran/ui/core/widgets/continue_listening_row.dart';
import 'package:holyquran/ui/core/widgets/home_door.dart';
import 'package:holyquran/ui/core/widgets/home_header.dart';
import 'package:holyquran/ui/core/widgets/share_card.dart';
import 'package:holyquran/ui/core/widgets/splash.dart';

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
          child: const SingleChildScrollView(child: HomeShareGallery()),
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

  testWidgets('titles its five sections and shows each widget', (tester) async {
    await _pump(tester);
    expect(
      tester
          .widgetList<GallerySection>(find.byType(GallerySection))
          .map((section) => section.title),
      [
        _l10n.gallerySectionHomeHeader,
        _l10n.gallerySectionHomeDoor,
        _l10n.gallerySectionContinueListeningRow,
        _l10n.gallerySectionShareCard,
        _l10n.gallerySectionSplash,
      ],
    );
    expect(find.byType(HomeHeader), findsOneWidget);
    expect(
      tester
          .widgetList<HomeDoor>(find.byType(HomeDoor))
          .map((door) => door.label),
      [_l10n.homeDoorIndex, _l10n.homeDoorBookmarks],
    );
    expect(
      tester
          .widgetList<ShareCard>(find.byType(ShareCard))
          .map((card) => card.design),
      ShareCardDesign.values,
    );
    expect(find.byType(Splash), findsOneWidget);
  });

  testWidgets('draws synthetic samples only', (tester) async {
    await _pump(tester);
    final rows = tester
        .widgetList<ContinueListeningRow>(find.byType(ContinueListeningRow))
        .toList();
    expect(rows.map((row) => row.surahName.verbatim), [
      _l10n.sampleSurahName,
      _l10n.sampleSurahName,
    ]);
    expect(rows.map((row) => row.reciter), [_l10n.sampleReciter, null]);
    for (final card in tester.widgetList<ShareCard>(find.byType(ShareCard))) {
      expect(card.ayah.verbatim, _l10n.sampleText, reason: card.design.name);
      expect(
        card.surahName.verbatim,
        _l10n.sampleSurahName,
        reason: card.design.name,
      );
    }
  });
}
