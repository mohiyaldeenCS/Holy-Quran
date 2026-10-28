import 'package:flutter/material.dart' hide IconButton;
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/gallery/gallery_screen.dart';
import 'package:holyquran/ui/core/gallery/gallery_section.dart';
import 'package:holyquran/ui/core/gallery/sections/study_search_gallery.dart';
import 'package:holyquran/ui/core/widgets/icon_button.dart';
import 'package:holyquran/ui/core/widgets/mode_chips.dart';
import 'package:holyquran/ui/core/widgets/quran_text.dart';
import 'package:holyquran/ui/core/widgets/search_field.dart';
import 'package:holyquran/ui/core/widgets/search_result.dart';
import 'package:holyquran/ui/core/widgets/search_summary.dart';
import 'package:holyquran/ui/core/widgets/word_sheet.dart';

import '../../../../testing/clip.dart';
import '../../../../testing/golden.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));
// .qk-result-body.is-clamped: max-height 92px at the default text size.
const _clampHeight = 92.0;

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
          child: const SingleChildScrollView(child: StudySearchGallery()),
        ),
      ),
    ),
  );
}

Finder _clampedAyah() => find.descendant(
  of: find.descendant(
    of: find.byType(SearchResult).last,
    matching: find.byType(QuranText),
  ),
  matching: find.byType(RichText),
);

RenderObject _lastResult(WidgetTester tester) =>
    tester.renderObject(find.byType(SearchResult).last);

void main() {
  // 400 is the width of the section's golden image.
  for (final width in [400.0, 360.0]) {
    testWidgets('the long result is cut where the gallery draws it, '
        '${width.round()} wide', (tester) async {
      tester.view
        ..physicalSize = Size(width, 2000)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        goldenApp(
          ReadingTheme.paper,
          const SingleChildScrollView(
            child: GalleryThemed(
              theme: ReadingTheme.paper,
              child: StudySearchGallery(),
            ),
          ),
        ),
      );
      final ayah = tester.renderObject<RenderBox>(_clampedAyah());
      expect(
        ayah.size.height - shownRect(ayah, _lastResult(tester)).height,
        greaterThanOrEqualTo(1),
      );
      // The cut is painted, not only declared.
      final result = find.byType(SearchResult).last;
      expect(
        result,
        paints
          ..clipRect(rect: cutClip(ayah, _lastResult(tester), _clampHeight)),
      );
      expect(result, paintsExactlyCountTimes(#clipRect, 1));
      expect(find.text(_l10n.searchResultShowWhole), findsOneWidget);
    });
  }

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
        _l10n.gallerySectionWordSheet,
        _l10n.gallerySectionSearchField,
        _l10n.gallerySectionModeChips,
        _l10n.gallerySectionSearchSummary,
        _l10n.gallerySectionSearchResult,
      ],
    );
    expect(find.byType(WordSheet), findsOneWidget);
    expect(find.byType(SearchField), findsNWidgets(2));
    expect(find.byType(ModeChips), findsOneWidget);
    expect(
      tester.widget<ModeChips>(find.byType(ModeChips)).label,
      _l10n.searchModesLabel,
    );
    expect(find.byType(SearchSummary), findsOneWidget);
    expect(
      tester
          .widgetList<SearchResult>(find.byType(SearchResult))
          .map((result) => result.clamp),
      [false, false, true],
    );
  });

  testWidgets('shows only synthetic samples', (tester) async {
    await _pump(tester);
    final sheet = tester.widget<WordSheet>(find.byType(WordSheet));
    expect(sheet.word, PackText.fromPack(_l10n.sampleWord));
    expect(sheet.tabs, WordSheetTab.values.toSet());
    for (final row in sheet.rows) {
      expect(row.label, _l10n.sampleRowLabel);
      expect(row.value, _l10n.sampleRowValue);
    }
    expect(sheet.note, _l10n.sampleNote);
    final summary = tester.widget<SearchSummary>(find.byType(SearchSummary));
    expect(summary.title, _l10n.sampleSearchTitle);
    expect(summary.count, _l10n.sampleSearchCount);
    for (final result in tester.widgetList<SearchResult>(
      find.byType(SearchResult),
    )) {
      expect(result.surahName, PackText.fromPack(_l10n.sampleSurahName));
      expect(
        result.ayahText,
        PackText.fromPack(
          result.clamp ? _l10n.sampleLongText : _l10n.sampleText,
        ),
      );
    }
  });

  testWidgets('a tab and a mode can be chosen', (tester) async {
    await _pump(tester);
    expect(
      tester.widget<WordSheet>(find.byType(WordSheet)).selectedTab,
      WordSheetTab.irab,
    );
    await tester.tap(find.text(_l10n.wordSheetTabText));
    await tester.pump();
    expect(
      tester.widget<WordSheet>(find.byType(WordSheet)).selectedTab,
      WordSheetTab.text,
    );

    expect(tester.widget<ModeChips>(find.byType(ModeChips)).selectedIndex, 1);
    await tester.tap(find.text(_l10n.searchModeWord));
    await tester.pump();
    expect(tester.widget<ModeChips>(find.byType(ModeChips)).selectedIndex, 0);
  });

  testWidgets('the filled field clears; the long result shows whole', (
    tester,
  ) async {
    await _pump(tester);
    final clear = find.descendant(
      of: find.byType(SearchField),
      matching: find.byType(IconButton),
    );
    expect(clear, findsOneWidget);
    await tester.ensureVisible(clear);
    await tester.tap(clear);
    await tester.pump();
    expect(clear, findsNothing);

    final more = find.text(_l10n.searchResultShowWhole);
    await tester.ensureVisible(more);
    await tester.tap(more);
    await tester.pump();
    expect(more, findsNothing);
    final ayah = tester.renderObject<RenderBox>(_clampedAyah());
    expect(
      shownRect(ayah, _lastResult(tester)).height,
      closeTo(ayah.size.height, 0.01),
    );
  });
}
