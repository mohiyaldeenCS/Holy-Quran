import 'dart:io';

import 'package:flutter/material.dart' hide Icon, IconButton;
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/word_span.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/widgets/match_highlight.dart';
import 'package:holyquran/ui/core/widgets/mode_chips.dart';
import 'package:holyquran/ui/core/widgets/quran_text.dart';
import 'package:holyquran/ui/core/widgets/search_result.dart';
import 'package:holyquran/ui/core/widgets/search_summary.dart';
import 'package:holyquran/utils/result.dart';

import '../../../../testing/fakes/fake_search_history_repository.dart';
import '../../../../testing/fakes/fake_search_repository.dart';
import '../index/index_fixture.dart';
import 'search_fixture.dart';
import 'search_harness.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

void main() {
  late Directory root;
  late IndexFixture fixture;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('search_screen_test');
    fixture = await IndexFixture.load(root);
  });
  tearDownAll(() async {
    fixture.close();
    await root.delete(recursive: true);
  });

  Future<void> search(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField).first, text);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
  }

  FakeSearchRepository finding() => searchFinding([
    hit(fixture, 2, 3, ranges: [(2, 3), (5, 5)]),
    hit(fixture, 2, 12),
    hit(fixture, 3, 1),
  ]);

  group('the screen', () {
    testWidgets('has a title, a back button, the field and its chips', (
      tester,
    ) async {
      await pumpSearchApp(tester, fixture, search: finding());

      expect(find.text(_l10n.searchTitle), findsOneWidget);
      expect(find.bySemanticsLabel(_l10n.back), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      final chips = tester.widgetList<ModeChips>(find.byType(ModeChips));
      expect(
        [for (final c in chips) c.options],
        [
          [_l10n.searchModeWord, _l10n.searchModeBare],
          [_l10n.searchScopeAll, _l10n.goToSurah, _l10n.goToJuz],
        ],
      );
      expect(find.byType(SearchSummary), findsNothing);
      expect(find.byType(SearchResult), findsNothing);
    });

    testWidgets('shows only the chips whose data the pack has', (tester) async {
      await pumpSearchApp(
        tester,
        fixture,
        search: FakeSearchRepository(kinds: const ['bare']),
      );

      final chips = tester.widgetList<ModeChips>(find.byType(ModeChips));
      expect(chips.first.options, [_l10n.searchModeBare]);
    });

    testWidgets('without a base pack shows its title alone', (tester) async {
      await pumpSearchApp(tester, fixture, search: finding(), withPack: false);

      expect(find.text(_l10n.searchTitle), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });
  });

  group('a search', () {
    testWidgets('shows what was searched, its count, and a card for each', (
      tester,
    ) async {
      await pumpSearchApp(tester, fixture, search: finding());
      await search(tester, query);

      final summary = tester.widget<SearchSummary>(find.byType(SearchSummary));
      expect(summary.title, query);
      expect(
        summary.count,
        _l10n.searchResultCount(
          _l10n.searchPlaces(4, arabicDigits(4)),
          _l10n.ayahCount(3, arabicDigits(3)),
        ),
      );
      expect(summary.sortLabel, _l10n.searchSortMushafOrder);
      expect(find.byType(SearchResult), findsNWidgets(3));
    });

    testWidgets('draws each ayah as the pack stores it, matches painted', (
      tester,
    ) async {
      await pumpSearchApp(tester, fixture, search: finding());
      await search(tester, query);

      final first = QuranAddress(fixture.index.riwaya, 2, 3);
      final stored = (await fixture.text.ayahText(first) as Ok<PackText>).value;
      final texts = tester.widgetList<QuranText>(find.byType(QuranText));
      final card = texts.firstWhere((t) => t.text == stored);
      final spans =
          (await fixture.text.words(first) as Ok<List<WordSpan>>).value;
      expect(
        [for (final m in card.matches) (m.start, m.end)],
        [(spans[1].start, spans[2].end), (spans[4].start, spans[4].end)],
      );
      expect(find.byType(MatchHighlight), findsNWidgets(3));
    });

    testWidgets('a long ayah is cut and shown whole on «اعرضها كاملة»', (
      tester,
    ) async {
      await pumpSearchApp(tester, fixture, search: finding());
      await search(tester, query);

      expect(find.text(_l10n.searchResultShowWhole), findsWidgets);
      await tester.tap(find.text(_l10n.searchResultShowWhole).first);
      await tester.pumpAndSettle();

      final results = tester.widgetList<SearchResult>(
        find.byType(SearchResult),
      );
      expect(results.where((r) => r.expanded), hasLength(1));
    });

    testWidgets('a card shown whole stays whole after scrolling away', (
      tester,
    ) async {
      final many = [for (var a = 1; a <= 12; a++) hit(fixture, 2, a)];
      await pumpSearchApp(tester, fixture, search: searchFinding(many));
      await search(tester, query);

      final list = find.byType(Scrollable).first;
      final link = find.text(_l10n.searchResultShowWhole);
      await tester.scrollUntilVisible(link, 300, scrollable: list);
      await tester.ensureVisible(link.first);
      await tester.pumpAndSettle();
      final card = find.ancestor(
        of: link.first,
        matching: find.byType(SearchResult),
      );
      final key = tester.widget<SearchResult>(card).ayahNumber;
      final cardKey = ValueKey(QuranAddress(fixture.index.riwaya, 2, key));
      expect(
        find.descendant(of: find.byKey(cardKey), matching: link),
        findsOneWidget,
      );
      await tester.tap(link.first);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: find.byKey(cardKey), matching: link),
        findsNothing,
      );
      expect(
        tester
            .widget<SearchResult>(
              find.descendant(
                of: find.byKey(cardKey),
                matching: find.byType(SearchResult),
              ),
            )
            .expanded,
        isTrue,
      );

      await tester.drag(list, const Offset(0, 5000));
      await tester.pumpAndSettle();
      expect(find.byKey(cardKey), findsNothing, reason: 'built away');
      await tester.scrollUntilVisible(
        find.byKey(cardKey),
        300,
        scrollable: list,
      );

      expect(
        tester
            .widget<SearchResult>(
              find.descendant(
                of: find.byKey(cardKey),
                matching: find.byType(SearchResult),
              ),
            )
            .expanded,
        isTrue,
      );
    });

    testWidgets('the order control goes through the three orders', (
      tester,
    ) async {
      await pumpSearchApp(tester, fixture, search: finding());
      await search(tester, query);

      String label() =>
          tester.widget<SearchSummary>(find.byType(SearchSummary)).sortLabel;
      expect(label(), _l10n.searchSortMushafOrder);
      await tester.tap(find.text(_l10n.searchSortMushafOrder));
      await tester.pumpAndSettle();
      expect(label(), _l10n.searchSortNearest);
      await tester.tap(find.text(_l10n.searchSortNearest));
      await tester.pumpAndSettle();
      expect(label(), _l10n.searchSortFrequent);
    });

    testWidgets('a scope is searched once its number is typed', (tester) async {
      final fake = finding();
      await pumpSearchApp(tester, fixture, search: fake);
      await search(tester, query);
      await tester.tap(find.text(_l10n.goToSurah));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '٢');
      await tester.pumpAndSettle();

      expect(fake.queries.last.scope.toString(), 'SurahScope(2)');
      await tester.enterText(find.byType(TextField).last, '99');
      await tester.pumpAndSettle();
      expect(
        find.text(_l10n.surahNumberNotFound(arabicDigits(99))),
        findsOneWidget,
      );
      expect(find.byType(SearchResult), findsNothing);
    });

    testWidgets('says so when nothing is found', (tester) async {
      await pumpSearchApp(tester, fixture, search: searchFinding(const []));
      await search(tester, query);

      expect(find.text(_l10n.noSearchResults), findsOneWidget);
      expect(find.byType(SearchSummary), findsNothing);
    });

    testWidgets('the buttons of a card open its context and the reader', (
      tester,
    ) async {
      final router = await pumpSearchApp(tester, fixture, search: finding());
      await search(tester, query);

      await tester.tap(find.bySemanticsLabel(_l10n.searchResultContext).first);
      await tester.pumpAndSettle();
      expect(router.state.uri.path, startsWith('/sheet/context/'));
      router.pop();
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel(_l10n.searchResultOpen).first);
      await tester.pumpAndSettle();
      expect(
        router.state.uri.path,
        Routes.mushafRead(QuranAddress(fixture.index.riwaya, 2, 3)),
      );
    });
  });

  group('a place typed in the field', () {
    testWidgets('opens the reader there', (tester) async {
      final fake = finding();
      final router = await pumpSearchApp(tester, fixture, search: fake);
      await search(tester, '2:3');

      expect(
        router.state.uri.path,
        Routes.mushafRead(QuranAddress(fixture.index.riwaya, 2, 3)),
      );
      expect(fake.queries, isEmpty);
    });

    testWidgets('that the edition lacks is refused in words', (tester) async {
      await pumpSearchApp(tester, fixture, search: finding());
      await search(tester, '9:1');

      expect(
        find.text(_l10n.surahNumberNotFound(arabicDigits(9))),
        findsOneWidget,
      );
      expect(find.byType(SearchResult), findsNothing);
    });
  });

  group('the history', () {
    testWidgets('lists the recent queries under its title, newest first', (
      tester,
    ) async {
      await pumpSearchApp(
        tester,
        fixture,
        search: finding(),
        history: FakeSearchHistoryRepository(['one', 'two']),
      );

      expect(find.text(_l10n.searchHistoryTitle), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('one')).dy,
        lessThan(tester.getTopLeft(find.text('two')).dy),
      );
    });

    testWidgets('a search is kept and chosen again', (tester) async {
      final history = FakeSearchHistoryRepository();
      final fake = finding();
      await pumpSearchApp(tester, fixture, search: fake, history: history);
      expect(find.text(_l10n.searchHistoryTitle), findsNothing);
      await search(tester, query);
      await tester.tap(find.bySemanticsLabel(_l10n.searchFieldClear));
      await tester.pumpAndSettle();

      expect(find.text(_l10n.searchHistoryTitle), findsOneWidget);
      await tester.tap(find.text(query));
      await tester.pumpAndSettle();
      expect(fake.queries, hasLength(2));
      expect(find.byType(SearchResult), findsNWidgets(3));
    });

    testWidgets('is cleared by its button, and then is not shown', (
      tester,
    ) async {
      final history = FakeSearchHistoryRepository(['one', 'two']);
      await pumpSearchApp(tester, fixture, search: finding(), history: history);
      await tester.tap(find.text(_l10n.searchHistoryClear));
      await tester.pumpAndSettle();

      expect(find.text(_l10n.searchHistoryTitle), findsNothing);
      expect(find.text('one'), findsNothing);
      expect(await history.queries(), isNotNull);
    });
  });

  group('at 200% text', () {
    testWidgets('lays out its results without overflow', (tester) async {
      await pumpSearchApp(
        tester,
        fixture,
        search: finding(),
        textScale: 2,
        size: const Size(360, 800),
      );
      await search(tester, query);

      expect(tester.takeException(), isNull);
      expect(find.byType(SearchResult), findsWidgets);
    });
  });

  testWidgets('Back leaves the screen', (tester) async {
    final router = await pumpSearchApp(tester, fixture, search: finding());
    await tester.tap(find.bySemanticsLabel(_l10n.back));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, Routes.study);
  });
}
