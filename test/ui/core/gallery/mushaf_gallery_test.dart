import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/gallery/gallery_samples.dart';
import 'package:holyquran/ui/core/gallery/sections/mushaf_gallery.dart';
import 'package:holyquran/ui/core/reader/interactive_surah_sliver.dart';
import 'package:holyquran/ui/core/widgets/ayah_marker.dart';
import 'package:holyquran/ui/core/widgets/ayah_row.dart';
import 'package:holyquran/ui/core/widgets/ayah_toolbar.dart';
import 'package:holyquran/ui/core/widgets/bookmark_ribbon.dart';
import 'package:holyquran/ui/core/widgets/quran_text.dart';
import 'package:holyquran/ui/core/widgets/surah_list_item.dart';
import 'package:holyquran/ui/core/widgets/surah_name.dart';

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
          child: const SingleChildScrollView(child: MushafGallery()),
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

  testWidgets('titles its sections', (tester) async {
    await _pump(tester);
    expect(find.text(_l10n.gallerySectionAyahRow), findsOneWidget);
    expect(find.text(_l10n.gallerySectionSurahListItem), findsOneWidget);
    expect(find.text(_l10n.gallerySectionQuranText), findsOneWidget);
  });

  testWidgets('shows the ayah toolbar plain and bookmarked, and the four '
      'ribbons', (tester) async {
    await _pump(tester);
    final toolbars = tester
        .widgetList<AyahToolbar>(find.byType(AyahToolbar))
        .toList();
    expect(toolbars.map((t) => t.bookmarked), [false, true]);
    expect(toolbars.first.onShare, isNotNull);
    expect(toolbars.last.onUndo, isNotNull);
    expect(find.byType(BookmarkRibbon), findsNWidgets(4));
  });

  testWidgets('shows AyahRow with every action and with one', (tester) async {
    await _pump(tester);
    final rows = tester.widgetList<AyahRow>(find.byType(AyahRow)).toList();
    expect(rows, hasLength(2));
    expect(rows.first.onBookmark, isNotNull);
    expect(rows.last.onBookmark, isNull);
  });

  testWidgets('shows SurahListItem plain, last read and without place or '
      'page', (tester) async {
    await _pump(tester);
    final items = tester.widgetList<SurahListItem>(find.byType(SurahListItem));
    expect(items.where((item) => item.lastRead), hasLength(1));
    expect(
      items.where((item) => item.page == null && item.revelation == null),
      hasLength(1),
    );
  });

  testWidgets('draws only the synthetic samples', (tester) async {
    await _pump(tester);
    final texts = {
      for (final quran in tester.widgetList<QuranText>(find.byType(QuranText)))
        quran.text,
    };
    expect(texts, {GallerySamples.text(_l10n), GallerySamples.longText(_l10n)});
    final names = {
      for (final name in tester.widgetList<SurahName>(find.byType(SurahName)))
        name.name,
    };
    expect(names, {GallerySamples.surahName(_l10n)});
  });

  testWidgets('offers the way back to the recitation', (tester) async {
    await _pump(tester);
    expect(find.text(_l10n.returnToRecitation), findsOneWidget);
  });

  testWidgets('shows the recited, selected and matched states of the text', (
    tester,
  ) async {
    await _pump(tester);
    final slivers = tester
        .widgetList<InteractiveSurahSliver>(find.byType(InteractiveSurahSliver))
        .toList();
    expect(slivers, hasLength(3));
    final states = [for (final s in slivers) s.highlights];
    expect(states.where((h) => h.recitedAyah != null), hasLength(1));
    expect(states.where((h) => h.spokenWord != null), hasLength(1));
    expect(states.where((h) => h.selectedAyah != null), hasLength(1));
    expect(states.where((h) => h.searchMatches.isNotEmpty), hasLength(1));
    final playing = tester
        .widgetList<AyahMarker>(find.byType(AyahMarker))
        .where((marker) => marker.playing);
    expect(playing, hasLength(1));
    for (final sliver in slivers) {
      expect(sliver.text.ayat.single.text, GallerySamples.text(_l10n));
    }
  });
}
