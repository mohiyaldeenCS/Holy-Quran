import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/app_theme.dart';
import 'package:holyquran/ui/core/widgets/level_switch.dart';
import 'package:holyquran/ui/core/widgets/quran_text.dart';
import 'package:holyquran/ui/core/widgets/surah_name.dart';
import 'package:holyquran/ui/core/widgets/word_sheet.dart';
import 'package:holyquran/utils/result.dart';

import '../../testing/clip.dart';
import '../s1/render/spike_surah_text.dart';
import '../s1/render/surah_list_v1.dart';
import '../s1/render/surah_text_block.dart';
import '../s1/render/synthetic_surah_pack.dart';
import 'ayah_toolbar_stand_in.dart';
import 'gesture_log.dart';
import 'gesture_target.dart';
import 's7_record.dart';
import 's7_session.dart';
import 'synthetic_pages.dart';
import 'tap_resolver.dart';
import 'target_geometry.dart';
import 'target_practice.dart';
import 'text_size_ladder.dart';
import 'waqf_card_stand_in.dart';

// Every text is Arabic-script nonsense with marks from the spike writer's
// synthetic pack (D-083), read through the app's verification and text
// repository.

const _width = 360.0;
const _height = 800.0;

/// Taps are looked for in this band: below the chrome, above the toolbar.
const _top = 140.0;
const _bottom = 620.0;

SpikeSurahText _first(SpikeSurahText surah, int ayat) => SpikeSurahText(
  firstAyah: surah.firstAyah,
  ayat: surah.ayat.sublist(0, ayat),
  words: surah.words.sublist(0, ayat),
  marks: surah.marks.sublist(0, ayat),
  basmala: surah.basmala,
  pageStarts: const {},
);

void main() {
  late Directory root;
  late S7Surah surah;
  late S7Surah short;
  final l10n = lookupAppLocalizations(const Locale('ar'));

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('s7_session');
    final read = await readSyntheticSurahs(root, withMarks: true);
    final name = switch (await read.pack.surahs()) {
      Ok(:final value) => value.first.name,
      Failure(:final error) => throw StateError('$error'),
    };
    surah = (text: _first(read.long, 60), name: name);
    final shortName = switch (await read.pack.surahs()) {
      Ok(:final value) => value[syntheticShortSurah - 1].name,
      Failure(:final error) => throw StateError('$error'),
    };
    short = (text: read.short, name: shortName);
    read.pack.close();
  });
  tearDownAll(() => root.delete(recursive: true));

  Future<S7Record> pump(
    WidgetTester tester, {
    bool pages = false,
    S7Surah? reading,
    bool reduceMotion = false,
    double textScale = 1,
    TapRule rule = s7DefaultTapRule,
    ReadingTheme theme = ReadingTheme.paper,
  }) async {
    var now = 0;
    final record = S7Record(log: GestureLog(clockMs: () => now += 5));
    tester.view
      ..physicalSize = const Size(_width, _height)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(theme),
        debugShowCheckedModeBanner: false,
        // As the spike launcher: English, left to right.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: reduceMotion,
          ),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: child!,
          ),
        ),
        home: S7Session(
          surah: pages ? null : reading ?? surah,
          record: record,
          storage: () async => Directory('${root.path}/storage'),
          random: Random(3),
          initialRule: rule,
        ),
      ),
    );
    // The reader's top inset follows the chrome's height after a frame.
    await tester.pump();
    return record;
  }

  RenderSurahTextBlock block(WidgetTester tester) =>
      tester.renderObject(find.byType(SurahTextBlock));

  Offset origin(WidgetTester tester) =>
      tester.getTopLeft(find.byType(SurahTextBlock));

  /// A point, in global coordinates, that [rule] resolves to a target of
  /// [kind] between [_top] and [_bottom], with that target.
  (Offset, GestureTarget) pointOf(
    WidgetTester tester,
    Type kind, {
    TapRule rule = s7DefaultTapRule,
  }) {
    final paragraph = block(tester).paragraph;
    final at = origin(tester);
    final g = TargetGeometry.of(paragraph);
    final centres = [
      for (final rects in g.words.values)
        if (rects.single.width > 0) rects.single.center,
      for (final rect in g.marks.values) rect.center,
      for (final rect in g.markers.values) rect.center,
    ];
    for (final centre in centres) {
      final global = at + centre;
      if (global.dy < _top || global.dy > _bottom) continue;
      final target = resolveTap(centre, g, rule);
      if (target.runtimeType == kind) return (global, target);
    }
    throw StateError('no $kind on screen');
  }

  double chromeOpacity(WidgetTester tester) => tester
      .widget<AnimatedOpacity>(
        find.ancestor(
          of: find.text('Debug'),
          matching: find.byType(AnimatedOpacity),
        ),
      )
      .opacity;

  SurahListV1 list(WidgetTester tester) =>
      tester.widget<SurahListV1>(find.byType(SurahListV1));

  Future<void> openPanel(WidgetTester tester) async {
    await tester.tap(find.text('Debug'));
    await tester.pumpAndSettle();
  }

  Future<void> closePanel(WidgetTester tester) async {
    tester.state<ScaffoldState>(find.byType(Scaffold)).closeEndDrawer();
    await tester.pumpAndSettle();
  }

  Future<void> setLevel(WidgetTester tester, S7Level level) async {
    await openPanel(tester);
    final labels = [l10n.levelSimple, l10n.levelMedium, l10n.levelStudy];
    await tester.tap(find.text(labels[level.index]));
    await tester.pump();
    await closePanel(tester);
  }

  group('actionFor', () {
    final word = WordTarget(QuranAddress('hafs', 1, 2, 3));
    final mark = WaqfMarkTarget(QuranAddress('hafs', 1, 2), 1);
    final marker = MarkerTarget(QuranAddress('hafs', 1, 2));
    const margin = MarginTarget();

    test('taps with the toolbar closed', () {
      for (final level in S7Level.values) {
        S7Action tap(GestureTarget t) =>
            actionFor(t, longPress: false, level: level, toolbarOpen: false);
        expect(
          tap(word),
          level == S7Level.simple
              ? S7Action.toggleChrome
              : S7Action.openWordSheet,
        );
        expect(tap(margin), S7Action.toggleChrome);
        expect(tap(marker), S7Action.selectAyah);
        expect(tap(mark), S7Action.openWaqfCard);
      }
    });

    test('long presses select the ayah, except on the margin', () {
      for (final level in S7Level.values) {
        for (final open in [false, true]) {
          S7Action press(GestureTarget t) =>
              actionFor(t, longPress: true, level: level, toolbarOpen: open);
          expect(press(word), S7Action.selectAyah);
          expect(press(mark), S7Action.selectAyah);
          expect(press(marker), S7Action.selectAyah);
          expect(press(margin), S7Action.none);
        }
      }
    });

    test('with the toolbar open a tap only closes it, except on a marker', () {
      for (final level in S7Level.values) {
        S7Action tap(GestureTarget t) =>
            actionFor(t, longPress: false, level: level, toolbarOpen: true);
        expect(tap(word), S7Action.closeToolbar);
        expect(tap(mark), S7Action.closeToolbar);
        expect(tap(margin), S7Action.closeToolbar);
        expect(tap(marker), S7Action.selectAyah);
      }
    });

    test('the logged hit is addresses and numbers', () {
      expect(loggedHitOf(word), (
        target: LoggedTarget.word,
        address: word.word,
        mark: null,
      ));
      expect(loggedHitOf(mark), (
        target: LoggedTarget.waqfMark,
        address: mark.ayah,
        mark: 1,
      ));
      expect(loggedHitOf(marker), (
        target: LoggedTarget.marker,
        address: marker.ayah,
        mark: null,
      ));
      expect(loggedHitOf(margin), (
        target: LoggedTarget.margin,
        address: null,
        mark: null,
      ));
    });
  });

  group('surah mode', () {
    testWidgets('simple: a word tap shows and hides the UI, and opens '
        'nothing', (tester) async {
      await pump(tester);
      expect(chromeOpacity(tester), 1);
      final (point, _) = pointOf(tester, WordTarget);
      await tester.tapAt(point);
      await tester.pumpAndSettle();
      expect(chromeOpacity(tester), 0);
      expect(list(tester).highlighted, isEmpty);
      await tester.tapAt(point);
      await tester.pumpAndSettle();
      expect(chromeOpacity(tester), 1);
      expect(find.byType(AyahToolbarStandIn), findsNothing);
    });

    for (final level in [S7Level.medium, S7Level.study]) {
      testWidgets('${level.name}: a word tap is logged and opens nothing, '
          'pending the word sheet, and leaves the UI', (tester) async {
        final record = await pump(tester);
        await setLevel(tester, level);
        final (point, target) = pointOf(tester, WordTarget);
        await tester.tapAt(point);
        await tester.pumpAndSettle();
        final entry = record.log.entries.single;
        expect(entry.target, LoggedTarget.word);
        expect(entry.address, (target as WordTarget).word);
        expect(find.byType(WordSheet), findsNothing);
        expect(list(tester).highlighted, isEmpty);
        expect(list(tester).selected, isEmpty);
        expect(chromeOpacity(tester), 1);
      });
    }

    testWidgets('the chrome covers no text at the top, and showing it moves '
        'nothing', (tester) async {
      await pump(tester);
      final bar = tester.getRect(
        find.ancestor(of: find.text('Debug'), matching: find.byType(Row)),
      );
      final top = origin(tester).dy;
      expect(top, greaterThanOrEqualTo(bar.bottom));
      await tester.tapAt(const Offset(4, _height / 2));
      await tester.pumpAndSettle();
      expect(chromeOpacity(tester), 0);
      expect(origin(tester).dy, top);
    });

    testWidgets('in a short surah a tap below the text is a margin tap', (
      tester,
    ) async {
      final record = await pump(tester, reading: short);
      final below = tester.getRect(find.byType(SurahTextBlock)).bottom;
      expect(below, lessThan(_height - 60));
      await tester.tapAt(const Offset(_width / 2, _height - 30));
      await tester.pumpAndSettle();
      expect(chromeOpacity(tester), 0);
      expect(record.log.entries.single.target, LoggedTarget.margin);
    });

    testWidgets('a long press on the gutter is a long press on the margin: '
        'logged, and nothing changes', (tester) async {
      final record = await pump(tester);
      await tester.longPressAt(const Offset(4, _height / 2));
      await tester.pumpAndSettle();
      final entry = record.log.entries.single;
      expect(entry.gesture, LoggedGesture.longPress);
      expect(entry.target, LoggedTarget.margin);
      expect(chromeOpacity(tester), 1);
      expect(find.byType(AyahToolbarStandIn), findsNothing);
    });

    testWidgets('changing the mode or the level closes the toolbar and the '
        'card', (tester) async {
      await pump(tester);
      final (marker, _) = pointOf(tester, MarkerTarget);
      await tester.tapAt(marker);
      await tester.pump();
      expect(find.byType(AyahToolbarStandIn), findsOneWidget);
      await setLevel(tester, S7Level.study);
      expect(
        find.byType(AyahToolbarStandIn),
        findsOneWidget,
        reason: 'the level keeps the selection',
      );
      await openPanel(tester);
      await tester.tap(find.text('Page'));
      await tester.pump();
      await tester.tap(find.text('Surah'));
      await tester.pump();
      await closePanel(tester);
      expect(find.byType(AyahToolbarStandIn), findsNothing);
      expect(list(tester).selected, isEmpty);
    });

    testWidgets('a tap on the gutter or the basmala shows and hides the UI', (
      tester,
    ) async {
      final record = await pump(tester);
      await tester.tapAt(const Offset(4, _height / 2));
      await tester.pumpAndSettle();
      expect(chromeOpacity(tester), 0);
      final basmala =
          origin(tester) +
          Offset(_width / 2, block(tester).paragraph.bodyTop / 2);
      await tester.tapAt(basmala);
      await tester.pumpAndSettle();
      expect(chromeOpacity(tester), 1);
      expect(
        [for (final e in record.log.entries) e.target],
        [LoggedTarget.margin, LoggedTarget.margin],
      );
    });

    testWidgets('a marker tap selects the ayah and opens the toolbar; a word '
        'tap then only closes it', (tester) async {
      final record = await pump(tester);
      final (point, target) = pointOf(tester, MarkerTarget);
      await tester.tapAt(point);
      await tester.pump();
      expect(list(tester).selected, {(target as MarkerTarget).ayah});
      expect(find.byType(AyahToolbarStandIn), findsOneWidget);

      await tester.tap(find.bySemanticsLabel(l10n.ayahRowBookmark));
      await tester.pump();
      expect(record.toolbarActions, {AyahToolbarAction.bookmark: 1});

      final (word, _) = pointOf(tester, WordTarget);
      await tester.tapAt(word);
      await tester.pumpAndSettle();
      expect(list(tester).selected, isEmpty);
      expect(find.byType(AyahToolbarStandIn), findsNothing);
      expect(chromeOpacity(tester), 1);
    });

    testWidgets('a long press on a word selects its ayah and opens the '
        'toolbar', (tester) async {
      final record = await pump(tester);
      final (point, target) = pointOf(tester, WordTarget);
      await tester.longPressAt(point);
      await tester.pump();
      expect(list(tester).selected, {(target as WordTarget).word.ayahAddress});
      expect(find.byType(AyahToolbarStandIn), findsOneWidget);
      expect(record.log.entries.single.gesture, LoggedGesture.longPress);
    });

    testWidgets('a mark tap opens the waqf card; the scrim closes it', (
      tester,
    ) async {
      await pump(tester);
      final (point, target) = pointOf(tester, WaqfMarkTarget);
      await tester.tapAt(point);
      await tester.pump();
      final card = tester.widget<WaqfCardStandIn>(find.byType(WaqfCardStandIn));
      target as WaqfMarkTarget;
      expect((card.ayah, card.mark), (target.ayah, target.mark));
      expect(card.surahName, same(surah.name));
      await tester.tapAt(const Offset(_width / 2, 200));
      await tester.pump();
      expect(find.byType(WaqfCardStandIn), findsNothing);
    });

    for (final (where, point) in [
      ('the text', const Offset(_width / 2, _height / 2)),
      ('the gutter', const Offset(4, _height / 2)),
    ]) {
      testWidgets('a tap on $where that stops a fling opens nothing and logs '
          'nothing', (tester) async {
        final record = await pump(tester);
        await setLevel(tester, S7Level.medium);
        final controller = list(tester).controller!;
        await tester.flingFrom(
          const Offset(_width / 2, 600),
          const Offset(0, -300),
          3000,
        );
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        final moving = controller.offset;
        await tester.pump(const Duration(milliseconds: 16));
        expect(controller.offset, greaterThan(moving), reason: 'flinging');
        await tester.tapAt(point);
        await tester.pumpAndSettle();
        expect(record.log.entries, isEmpty);
        expect(chromeOpacity(tester), 1);
      });
    }

    testWidgets('a pinch steps the size and keeps the focal ayah', (
      tester,
    ) async {
      final record = await pump(tester);
      list(tester).controller!.jumpTo(1500);
      await tester.pump();
      const focal = Offset(_width / 2, 400);
      final before = block(tester);
      final anchor = focalAyahAt(
        before.paragraph,
        before.globalToLocal(focal),
      )!;

      final first = await tester.startGesture(
        focal - const Offset(0, 30),
        pointer: 7,
      );
      final second = await tester.startGesture(
        focal + const Offset(0, 30),
        pointer: 8,
      );
      for (var i = 0; i < 10; i++) {
        await first.moveBy(const Offset(0, -5));
        await tester.pump(const Duration(milliseconds: 16));
        await second.moveBy(const Offset(0, 5));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await first.up();
      await second.up();
      await tester.pump();
      await tester.pump();

      final entry = record.log.entries.single;
      expect(entry.gesture, LoggedGesture.textPinch);
      expect(entry.address, anchor.ayah);
      final step = stepAfterPinch(1, entry.scale!);
      expect(step, greaterThan(1));
      expect(entry.textSize, step);
      expect(
        MediaQuery.textScalerOf(tester.element(find.byType(SurahTextBlock))),
        TextScaler.linear(step),
      );
      final after = block(tester);
      final y = yOfFocalAyah(after.paragraph, anchor)!;
      expect(after.localToGlobal(Offset(0, y)).dy, closeTo(focal.dy, 0.5));
    });

    testWidgets('the system scale picks the first step, which then replaces '
        'it', (tester) async {
      await pump(tester, textScale: 1.4);
      expect(
        MediaQuery.textScalerOf(tester.element(find.byType(SurahTextBlock))),
        TextScaler.linear(stepAfterPinch(1.4, 1)),
      );
    });
  });

  group('page mode', () {
    testWidgets('a tap shows and hides the UI; a drag turns; both are '
        'logged with 1-based pages', (tester) async {
      final record = await pump(tester, pages: true);
      expect(find.byType(SyntheticPages), findsOneWidget);
      expect(find.byType(SurahName), findsNothing);
      await tester.tapAt(const Offset(_width / 2, _height / 2));
      await tester.pumpAndSettle();
      expect(chromeOpacity(tester), 0);

      final drag = await tester.startGesture(
        const Offset(_width / 2, _height / 2),
      );
      await drag.moveBy(const Offset(40, 0));
      for (var i = 0; i < 6; i++) {
        await drag.moveBy(const Offset(30, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await drag.up();
      await tester.pumpAndSettle();

      final [tap, turn] = record.log.entries;
      expect(tap.gesture, LoggedGesture.tap);
      expect(tap.target, LoggedTarget.pageLine);
      expect(tap.page, 1);
      expect(tap.line, isNotNull);
      expect(turn.gesture, LoggedGesture.pageTurn);
      expect((turn.page, turn.toPage, turn.scale), (1, 2, 1.0));
    });

    testWidgets('a pinch zooms the page and is logged', (tester) async {
      final record = await pump(tester, pages: true);
      final first = await tester.startGesture(
        const Offset(_width / 2, 360),
        pointer: 7,
      );
      final second = await tester.startGesture(
        const Offset(_width / 2, 440),
        pointer: 8,
      );
      for (var i = 0; i < 10; i++) {
        await first.moveBy(const Offset(0, -8));
        await second.moveBy(const Offset(0, 8));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await first.up();
      await second.up();
      await tester.pumpAndSettle();
      final zoom = record.log.entries.singleWhere(
        (e) => e.gesture == LoggedGesture.pageZoom,
      );
      expect(zoom.page, 1);
      expect(zoom.scale, greaterThan(1));
    });
  });

  group('reduce motion', () {
    for (final reduce in [true, false]) {
      testWidgets('the UI ${reduce ? 'appears and goes at once' : 'fades'}', (
        tester,
      ) async {
        final record = await pump(tester, reduceMotion: reduce);
        await tester.tapAt(const Offset(4, _height / 2));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        final opacity = tester
            .renderObject<RenderAnimatedOpacity>(
              find.ancestor(
                of: find.text('Debug'),
                matching: find.byType(AnimatedOpacity),
              ),
            )
            .opacity
            .value;
        if (reduce) {
          expect(opacity, 0);
        } else {
          expect(opacity, inExclusiveRange(0, 1));
        }
        expect(record.log.entries.single.context, 0);
        await tester.pumpAndSettle();
      });
    }

    testWidgets('the log context records the setting', (tester) async {
      final record = await pump(tester, reduceMotion: true);
      await tester.tapAt(const Offset(4, _height / 2));
      await tester.pump();
      expect(
        (record.log.toJson()['contexts']! as List)
            .cast<Map<String, Object?>>()
            .single,
        containsPair('disable_animations', true),
      );
    });
  });

  group('the log', () {
    testWidgets('one entry per gesture with the target, the rule, the size '
        'and the point', (tester) async {
      final record = await pump(tester);
      final (point, target) = pointOf(tester, WordTarget);
      await tester.tapAt(point);
      await tester.pump();
      final (markPoint, mark) = pointOf(tester, WaqfMarkTarget);
      await tester.tapAt(markPoint);
      await tester.pump();
      await tester.tapAt(const Offset(_width / 2, 200));
      await tester.pump();

      final [word, waqf] = record.log.entries;
      expect(word.gesture, LoggedGesture.tap);
      expect(word.target, LoggedTarget.word);
      expect(word.address, (target as WordTarget).word);
      expect(word.mark, isNull);
      expect(word.rule, s7DefaultTapRule.name);
      expect(word.textSize, 1);
      expect(word.point, block(tester).globalToLocal(point));
      expect(word.context, isNotNull);
      expect(word.isTrial, isFalse);
      expect(waqf.target, LoggedTarget.waqfMark);
      mark as WaqfMarkTarget;
      expect((waqf.address, waqf.mark), (mark.ayah, mark.mark));
      expect(word.downMs, isNotNull);
      expect(word.upMs, isNotNull);
    });

    testWidgets('a rule chosen in the panel is the next entry\'s', (
      tester,
    ) async {
      final record = await pump(tester);
      await openPanel(tester);
      expect(find.text('${s7DefaultTapRule.name} (default)'), findsOneWidget);
      await tester.tap(find.text(TapRule.exact.name));
      await tester.pump();
      await closePanel(tester);
      await tester.tapAt(const Offset(4, _height / 2));
      await tester.pump();
      expect(record.log.entries.single.rule, TapRule.exact.name);
    });
  });

  group('target practice', () {
    testWidgets('a ringed target is asked for; a tap on it is a hit, a tap '
        'elsewhere a miss; nothing opens', (tester) async {
      final record = await pump(tester, rule: TapRule.exact);
      await openPanel(tester);
      await tester.tap(find.text('Start practice'));
      await tester.pumpAndSettle();
      expect(chromeOpacity(tester), 0);

      final ring = tester.widget<PracticeRing>(find.byType(PracticeRing));
      final viewport = tester.getRect(find.byType(SurahListV1));
      final box = ring.box.shift(origin(tester));
      expect(viewport.contains(box.topLeft), isTrue);
      expect(viewport.contains(box.bottomRight), isTrue);
      final kind = switch (resolveTap(
        ring.box.center,
        TargetGeometry.of(block(tester).paragraph),
        TapRule.exact,
      )) {
        WordTarget() => LoggedTarget.word,
        WaqfMarkTarget() => LoggedTarget.waqfMark,
        MarkerTarget() => LoggedTarget.marker,
        MarginTarget() => LoggedTarget.margin,
      };
      expect(find.textContaining('Tap the ringed ${kind.name}'), findsOne);

      await tester.tapAt(box.center);
      await tester.pump();
      await tester.tapAt(const Offset(4, _height / 2));
      await tester.pump();

      final [hit, miss] = record.log.entries;
      expect(hit.isTrial, isTrue);
      expect(hit.expectedTarget, kind);
      expect(hit.isHit, isTrue);
      expect(miss.isTrial, isTrue);
      expect(miss.isHit, isFalse);
      expect(find.textContaining('(1 of 2 hit)'), findsOneWidget);
      expect(hitRatesByRule(record.log.entries), {
        TapRule.exact.name: (trials: 2, hits: 1),
      });
      expect(find.byType(AyahToolbarStandIn), findsNothing);
      expect(find.byType(WaqfCardStandIn), findsNothing);
      expect(list(tester).selected, isEmpty);

      final first = await tester.startGesture(
        const Offset(_width / 2, 370),
        pointer: 7,
      );
      final second = await tester.startGesture(
        const Offset(_width / 2, 430),
        pointer: 8,
      );
      for (var i = 0; i < 10; i++) {
        await first.moveBy(const Offset(0, -5));
        await tester.pump(const Duration(milliseconds: 16));
        await second.moveBy(const Offset(0, 5));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await first.up();
      await second.up();
      await tester.pumpAndSettle();
      final after = tester.widget<PracticeRing>(find.byType(PracticeRing));
      final shown = after.box.shift(origin(tester));
      final reader = tester.getRect(find.byType(SurahListV1));
      expect(reader.contains(shown.topLeft), isTrue, reason: 'picked again');
      expect(reader.contains(shown.bottomRight), isTrue);
    });
  });

  group('text and access', () {
    /// Every text drawn outside QuranText, SurahName and WordSheet.
    List<String> otherTexts(WidgetTester tester) => [
      for (final element in find.byType(RichText).evaluate())
        if (find
            .ancestor(
              of: find.byWidget(element.widget),
              matching: find.byWidgetPredicate(
                (w) => w is QuranText || w is SurahName || w is WordSheet,
              ),
            )
            .evaluate()
            .isEmpty)
          (element.widget as RichText).text.toPlainText(),
    ];

    testWidgets('no text outside QuranText, SurahName and WordSheet comes '
        'from the pack', (tester) async {
      await pump(tester);
      final (marker, _) = pointOf(tester, MarkerTarget);
      await tester.tapAt(marker);
      await tester.pump();
      final texts = otherTexts(tester);
      final (word, _) = pointOf(tester, WordTarget);
      await tester.tapAt(word);
      await tester.pump();
      expect(find.byType(AyahToolbarStandIn), findsNothing);
      final (mark, _) = pointOf(tester, WaqfMarkTarget);
      await tester.tapAt(mark);
      await tester.pump();
      expect(find.byType(WaqfCardStandIn), findsOneWidget);
      texts.addAll(otherTexts(tester));
      await tester.tapAt(const Offset(_width / 2, 200));
      await tester.pump();
      await openPanel(tester);
      texts.addAll(otherTexts(tester));
      final pack = <PackText>[
        ...surah.text.ayat,
        ?surah.text.basmala,
        surah.name,
      ];
      expect(texts, isNotEmpty);
      for (final text in texts.where((t) => t.trim().length >= 3)) {
        for (final value in pack) {
          expect(
            value.verbatim.contains(text),
            isFalse,
            reason: 'a debug or chrome text is part of the pack text',
          );
        }
      }
    });

    for (final theme in ReadingTheme.values) {
      testWidgets('every hit area of the chrome is at least 48 in '
          '${theme.name}', (tester) async {
        final handle = tester.ensureSemantics();
        await pump(tester, theme: theme);
        final (marker, _) = pointOf(tester, MarkerTarget);
        await tester.tapAt(marker);
        await tester.pump();
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await openPanel(tester);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        handle.dispose();
      });
    }

    testWidgets('at 200% text nothing in the chrome is cut', (tester) async {
      await pump(tester, textScale: 2);
      final (word, _) = pointOf(tester, WordTarget);
      await tester.longPressAt(word);
      await tester.pump();
      expect(tester.takeException(), isNull);
      final within = tester.renderObject(find.byType(S7Session));
      for (final finder in [
        find.text('Debug'),
        find.byType(SurahName),
        find.byType(AyahToolbarStandIn),
      ]) {
        final box = tester.renderObject<RenderBox>(finder.first);
        expect(
          shownRect(box, within),
          tester.getRect(finder.first),
          reason: '$finder',
        );
      }
      await openPanel(tester);
      expect(tester.takeException(), isNull);
      final level = find.byType(LevelSwitch);
      expect(
        shownRect(tester.renderObject<RenderBox>(level), within),
        tester.getRect(level),
      );
    });
  });
}
