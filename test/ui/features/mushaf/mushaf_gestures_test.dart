import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:holyquran/domain/models/bookmark.dart';
import 'package:holyquran/domain/models/category.dart';
import 'package:holyquran/domain/models/pack_integrity.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/domain/models/ui_level.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/ui/core/reader/block_layout.dart';
import 'package:holyquran/ui/core/reader/margin_mark.dart';
import 'package:holyquran/ui/core/reader/reader_block.dart';
import 'package:holyquran/ui/core/reader/reader_text_scale.dart';
import 'package:holyquran/ui/core/reader/target_geometry.dart';
import 'package:holyquran/ui/core/widgets/ayah_marker.dart';
import 'package:holyquran/ui/core/widgets/ayah_toolbar.dart';
import 'package:holyquran/ui/core/widgets/bookmark_ribbon.dart';
import 'package:holyquran/ui/core/widgets/position_bar.dart';
import 'package:holyquran/ui/features/mushaf/view_models/mushaf_view_model.dart';
import 'package:holyquran/utils/result.dart';

import '../../../../testing/fakes/fake_app_settings_repository.dart';
import '../../../../testing/fakes/fake_bookmark_repository.dart';
import '../../../../testing/fakes/fake_category_repository.dart';
import '../../../../testing/fakes/fake_keep_awake_repository.dart';
import 'mushaf_harness.dart';

/// A widget test with semantics on, for finding the toolbar by its labels.
void readerTest(String name, Future<void> Function(WidgetTester tester) body) =>
    testWidgets(name, (tester) async {
      final semantics = tester.ensureSemantics();
      await body(tester);
      semantics.dispose();
    });

const _allTools = AyahTools(play: true, copy: true, share: true);

void main() {
  late Directory root;
  late MushafRig rig;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('mushaf_gestures');
    rig = await MushafRig.load(root);
  });
  tearDownAll(() async {
    rig.close();
    await root.delete(recursive: true);
  });

  QuranAddress at(int surah, int ayah) => QuranAddress('hafs', surah, ayah);

  late FakeAppSettingsRepository settings;
  late FakeBookmarkRepository bookmarks;
  late FakeKeepAwakeRepository keepAwake;
  late SheetLog sheets;
  late MushafViewModel viewModel;
  late GoRouter router;

  Future<void> pumpReader(
    WidgetTester tester, {
    UiLevel level = UiLevel.simple,
    AyahTools tools = _allTools,
    Set<String> without = const {},
    double textScale = 1,
    Iterable<Bookmark> existing = const [],
  }) async {
    setReaderView(tester);
    settings = FakeAppSettingsRepository(level: level);
    bookmarks = FakeBookmarkRepository(bookmarks: existing);
    keepAwake = FakeKeepAwakeRepository();
    sheets = SheetLog();
    viewModel = rig.viewModel(
      address: at(2, 1),
      settings: settings,
      bookmarks: bookmarks,
      categories: FakeCategoryRepository(),
      keepAwake: keepAwake,
      tools: tools,
    );
    addTearDown(viewModel.dispose);
    router = sheets.router(viewModel, without: without);
    addTearDown(router.dispose);
    await tester.pumpWidget(readerRouterApp(router, textScale: textScale));
    await tester.pumpAndSettle();
  }

  BlockLayout firstBlock(WidgetTester tester) =>
      tester.widget<ReaderBlock>(find.byType(ReaderBlock).first).layout;

  Offset wordPoint(WidgetTester tester) {
    final layout = firstBlock(tester);
    final origin = tester.getTopLeft(find.byType(ReaderBlock).first);
    final rect = TargetGeometry.of(layout).words.values.firstWhere(
      (r) => (origin + r.center).dy < readerHeight - 160,
    );
    return origin + rect.center;
  }

  Finder marker(int ayah) => find.byWidgetPredicate(
    (w) => w is AyahMarker && w.number == ayah && !w.playing,
  );

  Offset markerPoint(WidgetTester tester, int ayah) =>
      tester.getCenter(marker(ayah).first);

  // A point inside the text column's start margin, level with a line.
  Offset marginPoint(WidgetTester tester) => Offset(6, wordPoint(tester).dy);

  Finder toolbar() => find.byType(AyahToolbar);

  Future<void> longPress(WidgetTester tester, Offset point) async {
    await tester.longPressAt(point);
    await tester.pumpAndSettle();
  }

  group('what the reader shows (LV-03)', () {
    readerTest('at the simple level only the position bar and the text, '
        'until an ayah is chosen', (tester) async {
      await pumpReader(tester);
      expect(find.byType(PositionBar), findsOneWidget);
      expect(find.byType(ReaderBlock), findsWidgets);
      expect(toolbar(), findsNothing);
      expect(find.byType(BookmarkRibbon), findsNothing);
    });

    readerTest('the margin marks stand beside their lines', (tester) async {
      await pumpReader(tester);
      expect(find.byType(MarginMarkView), findsWidgets);
    });

    for (final theme in ReadingTheme.values) {
      readerTest('draws the selection and its toolbar in ${theme.name} at '
          '200%', (tester) async {
        await pumpReader(tester, textScale: 2);
        viewModel.select(at(2, 2));
        await tester.pumpWidget(
          readerRouterApp(router, theme: theme, textScale: 2),
        );
        await tester.pumpAndSettle();
        expect(toolbar(), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('selecting an ayah', () {
    readerTest('a long press on a word selects its ayah and opens its '
        'toolbar', (tester) async {
      await pumpReader(tester);
      expect(toolbar(), findsNothing);
      await longPress(tester, wordPoint(tester));
      final selected = viewModel.selectedAyah!;
      expect(selected.surah, 2);
      expect(selected.isWord, isFalse);
      expect(toolbar(), findsOneWidget);
      final selectedMarkers = tester
          .widgetList<AyahMarker>(find.byType(AyahMarker))
          .where((m) => m.selected);
      expect(selectedMarkers.map((m) => m.number), [selected.ayah]);
    });

    readerTest('a tap on a marker selects its ayah', (tester) async {
      await pumpReader(tester);
      await tester.tapAt(markerPoint(tester, 2));
      await tester.pumpAndSettle();
      expect(viewModel.selectedAyah, at(2, 2));
      expect(toolbar(), findsOneWidget);
    });

    readerTest('a tap elsewhere dismisses the selection and does not toggle '
        'the interface', (tester) async {
      await pumpReader(tester);
      await longPress(tester, wordPoint(tester));
      await tester.tapAt(wordPoint(tester));
      await tester.pumpAndSettle();
      expect(viewModel.selectedAyah, isNull);
      expect(toolbar(), findsNothing);
      expect(viewModel.distractionFree, isFalse);
    });

    readerTest('a screen reader reaches the toolbar through a marker', (
      tester,
    ) async {
      await pumpReader(tester);
      tester.semantics.tap(find.semantics.byLabel('الآية ٣'));
      await tester.pumpAndSettle();
      expect(viewModel.selectedAyah, at(2, 3));
      expect(toolbar(), findsOneWidget);
    });
  });

  group('taps by level (PRD §7.4)', () {
    readerTest('on the margin toggle the interface (RD-09)', (tester) async {
      await pumpReader(tester);
      expect(find.byType(PositionBar), findsOneWidget);
      await tester.tapAt(marginPoint(tester));
      await tester.pumpAndSettle();
      expect(viewModel.distractionFree, isTrue);
      expect(find.byType(PositionBar), findsNothing);
      await tester.tapAt(marginPoint(tester));
      await tester.pumpAndSettle();
      expect(viewModel.distractionFree, isFalse);
      expect(find.byType(PositionBar), findsOneWidget);
    });

    readerTest('the touch that stops a fling is no tap', (tester) async {
      await pumpReader(tester);
      await longPress(tester, wordPoint(tester));
      expect(viewModel.selectedAyah, isNotNull);
      await tester.fling(
        find.byType(CustomScrollView),
        const Offset(0, -300),
        2000,
      );
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(const Offset(6, 300));
      await tester.pumpAndSettle();
      expect(viewModel.selectedAyah, isNotNull, reason: 'not dismissed');
      expect(viewModel.distractionFree, isFalse);
      // At rest, the same touch is a tap.
      await tester.tapAt(const Offset(6, 300));
      await tester.pumpAndSettle();
      expect(viewModel.selectedAyah, isNull);
    });

    readerTest('a long hold on the margin is no tap', (tester) async {
      await pumpReader(tester);
      await tester.longPressAt(const Offset(6, 300));
      await tester.pumpAndSettle();
      expect(viewModel.distractionFree, isFalse);
      expect(viewModel.selectedAyah, isNull);
    });

    readerTest('on a word toggle the interface at the simple level', (
      tester,
    ) async {
      await pumpReader(tester);
      await tester.tapAt(wordPoint(tester));
      await tester.pumpAndSettle();
      expect(viewModel.distractionFree, isTrue);
      expect(sheets.opened, isEmpty);
    });

    for (final level in [UiLevel.medium, UiLevel.study]) {
      readerTest('on a word open its sheet at the ${level.name} level', (
        tester,
      ) async {
        await pumpReader(tester, level: level);
        await tester.tapAt(wordPoint(tester));
        await tester.pumpAndSettle();
        expect(sheets.opened, hasLength(1));
        expect(sheets.opened.single, startsWith('/sheet/word/hafs:2:'));
        expect(viewModel.distractionFree, isFalse);
      });
    }

    readerTest('on a word toggle the interface where the word sheet has no '
        'route yet', (tester) async {
      await pumpReader(
        tester,
        level: UiLevel.medium,
        without: {RoutePaths.wordSheet},
      );
      await tester.tapAt(wordPoint(tester));
      await tester.pumpAndSettle();
      expect(viewModel.distractionFree, isTrue);
    });

    readerTest('the position bar opens go-to where that sheet has a route', (
      tester,
    ) async {
      await pumpReader(tester);
      final bar = find.bySemanticsLabel(RegExp('^اذهب إلى'));
      expect(bar, findsOneWidget);
      final node = tester.getSemantics(bar);
      // The bar keeps its own text for a screen reader: the juz and hizb.
      expect(node.label, contains('الجزء'));
      expect(node.label, contains('الحزب'));
      expect(node.getSemanticsData().flagsCollection.isButton, isTrue);
      expect(tester.getSize(bar).height, greaterThanOrEqualTo(48));
      await tester.tap(find.byType(PositionBar));
      await tester.pumpAndSettle();
      expect(sheets.opened, [Routes.goToSheet]);
    });

    readerTest('a screen reader activates the position bar', (tester) async {
      await pumpReader(tester);
      tester.semantics.tap(find.semantics.byLabel(RegExp('^اذهب إلى')));
      await tester.pumpAndSettle();
      expect(sheets.opened, [Routes.goToSheet]);
    });

    readerTest('the position bar is no button without that route', (
      tester,
    ) async {
      await pumpReader(tester, without: {RoutePaths.goToSheet});
      await tester.tap(find.byType(PositionBar));
      await tester.pumpAndSettle();
      expect(sheets.opened, isEmpty);
    });
  });

  group('the toolbar', () {
    Future<void> select(WidgetTester tester) async {
      await tester.tapAt(markerPoint(tester, 2));
      await tester.pumpAndSettle();
    }

    readerTest('opens the play options, copy, share and study sheets of the '
        'ayah', (tester) async {
      await pumpReader(tester);
      await select(tester);
      for (final label in ['تشغيل', 'دراسة', 'نسخ', 'مشاركة']) {
        await tester.tap(find.bySemanticsLabel(label));
        await tester.pumpAndSettle();
        router.pop();
        await tester.pumpAndSettle();
      }
      expect(sheets.opened, [
        Routes.playOptionsSheet(at(2, 2)),
        Routes.ayahSheet(at(2, 2)),
        Routes.copySheet(at(2, 2)),
        Routes.shareSheet(at(2, 2)),
      ]);
    });

    readerTest('leaves out the tools that have no sheet or cannot work', (
      tester,
    ) async {
      await pumpReader(
        tester,
        tools: const AyahTools(copy: true),
        without: {RoutePaths.ayahSheet},
      );
      await select(tester);
      expect(find.bySemanticsLabel('تشغيل'), findsNothing);
      expect(find.bySemanticsLabel('دراسة'), findsNothing);
      expect(find.bySemanticsLabel('مشاركة'), findsNothing);
      expect(find.bySemanticsLabel('نسخ'), findsOneWidget);
      expect(find.bySemanticsLabel('علامة'), findsOneWidget);
    });

    readerTest('every button has a 48 hit area and a label', (tester) async {
      await pumpReader(tester, textScale: 2);
      viewModel.select(at(2, 2));
      await tester.pumpAndSettle();
      for (final label in ['تشغيل', 'علامة', 'دراسة', 'نسخ', 'مشاركة']) {
        final size = tester.getSize(find.bySemanticsLabel(label));
        expect(size.shortestSide, greaterThanOrEqualTo(48), reason: label);
      }
      expect(tester.takeException(), isNull);
    });
  });

  group('the bookmark (UD-05, D-128 8)', () {
    Future<void> tapBookmark(WidgetTester tester) async {
      await tester.tap(find.bySemanticsLabel('علامة'));
      await tester.pumpAndSettle();
    }

    readerTest('two taps make it in «حفظ» the first time, and its ribbon '
        'shows', (tester) async {
      await pumpReader(tester);
      expect(find.byType(BookmarkRibbon), findsNothing);
      await longPress(tester, markerPoint(tester, 2));
      await tapBookmark(tester);
      final made =
          (await bookmarks.bookmarkAt(at(2, 2)) as Ok<Bookmark?>).value!;
      expect(made.categoryId, 'fake-memorise');
      expect(find.byType(BookmarkRibbon), findsOneWidget);
      expect(tester.widget<AyahToolbar>(toolbar()).bookmarked, isTrue);
    });

    readerTest('takes the category of the newest bookmark', (tester) async {
      final older = Bookmark(
        id: 'b0',
        address: at(2, 7),
        categoryId: 'fake-review',
        tagIds: const {},
        createdAt: DateTime.utc(2030),
        updatedAt: DateTime.utc(2030),
      );
      await pumpReader(tester, existing: [older]);
      await tester.tapAt(markerPoint(tester, 2));
      await tester.pumpAndSettle();
      await tapBookmark(tester);
      final made =
          (await bookmarks.bookmarkAt(at(2, 2)) as Ok<Bookmark?>).value!;
      expect(made.categoryId, 'fake-review');
    });

    readerTest('a second tap removes it, and undo brings it back', (
      tester,
    ) async {
      await pumpReader(tester);
      await tester.tapAt(markerPoint(tester, 2));
      await tester.pumpAndSettle();
      await tapBookmark(tester);
      await tapBookmark(tester);
      expect(find.byType(BookmarkRibbon), findsNothing);
      expect(find.bySemanticsLabel('تراجع'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('تراجع'));
      await tester.pumpAndSettle();
      expect(find.byType(BookmarkRibbon), findsOneWidget);
      expect(find.bySemanticsLabel('تراجع'), findsNothing);
    });

    readerTest('a bookmark the store refuses is said in words', (tester) async {
      await pumpReader(tester);
      await tester.tapAt(markerPoint(tester, 2));
      await tester.pumpAndSettle();
      bookmarks.failure = Exception('closed');
      await tapBookmark(tester);
      expect(
        find.text(lookupAppLocalizations(const Locale('ar')).userDataNotSaved),
        findsOneWidget,
      );
      expect(find.byType(BookmarkRibbon), findsNothing);
    });

    readerTest('an existing bookmark shows its ribbon with its category', (
      tester,
    ) async {
      final existing = Bookmark(
        id: 'b0',
        address: at(2, 2),
        categoryId: 'fake-study',
        tagIds: const {},
        createdAt: DateTime.utc(2030),
        updatedAt: DateTime.utc(2030),
      );
      await pumpReader(tester, existing: [existing]);
      expect(find.byType(BookmarkRibbon), findsOneWidget);
      expect(tester.getSemantics(find.byType(BookmarkRibbon)).value, 'دراسة');
      expect(BuiltinCategory.study.key, 'study');
    });
  });

  group('the screen stays on while reading (RD-16)', () {
    readerTest('the reader holds it while shown and lets go when closed', (
      tester,
    ) async {
      await pumpReader(tester);
      expect(keepAwake.readerActive, isTrue);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(keepAwake.readerActive, isFalse);
    });
  });

  group('the screen is not kept on for a reader with no text', () {
    readerTest('a reader whose pack stops serving lets go', (tester) async {
      await pumpReader(tester);
      expect(keepAwake.readerActive, isTrue);
      addTearDown(
        () => rig.integrity.report(MushafRig.packId, const IntegrityOk()),
      );
      rig.integrity.report(MushafRig.packId, const IntegrityRepairing());
      await tester.pumpAndSettle();
      expect(viewModel.status, ReaderStatus.unavailable);
      expect(keepAwake.readerActive, isFalse);
    });
  });

  group('pinch (RD-07)', () {
    Future<void> pinch(WidgetTester tester, double from, double to) async {
      const centre = Offset(180, 320);
      final a = await tester.startGesture(centre - Offset(from / 2, 0));
      final b = await tester.startGesture(centre + Offset(from / 2, 0));
      await tester.pump();
      await a.moveTo(centre - Offset(to / 2, 0));
      await b.moveTo(centre + Offset(to / 2, 0));
      await tester.pump();
      await a.up();
      await b.up();
      await tester.pumpAndSettle();
    }

    readerTest('spreading steps the size up and keeps it as the setting', (
      tester,
    ) async {
      await pumpReader(tester);
      expect(viewModel.textStep, defaultReaderTextStep);
      await pinch(tester, 60, 120);
      expect(viewModel.textStep, greaterThan(defaultReaderTextStep));
      expect(settings.surahTextScale, readerTextSteps[viewModel.textStep]);
    });

    readerTest('pinching in steps it down to at least 80%', (tester) async {
      await pumpReader(tester);
      await pinch(tester, 200, 20);
      expect(viewModel.textStep, 0);
      expect(settings.surahTextScale, 0.8);
    });

    readerTest('a reader opens at the size last chosen', (tester) async {
      setReaderView(tester);
      final chosen = FakeAppSettingsRepository(surahTextScale: 1.5);
      final model = rig.viewModel(address: at(2, 1), settings: chosen);
      addTearDown(model.dispose);
      expect(readerTextSteps[model.textStep], 1.5);
    });

    readerTest('a reader under another follows the size chosen over it', (
      tester,
    ) async {
      await pumpReader(tester);
      final over = rig.viewModel(address: at(2, 1), settings: settings);
      addTearDown(over.dispose);
      over.setTextStep(5);
      await tester.pumpAndSettle();
      expect(over.textStep, 5);
      expect(viewModel.textStep, 5);
      expect(settings.surahTextScale, readerTextSteps[5]);
      over.setTextStep(1);
      over.setTextStep(6);
      await tester.pumpAndSettle();
      expect(over.textStep, 6, reason: 'its own write is not heard again');
      expect(viewModel.textStep, 6);
    });
  });
}
