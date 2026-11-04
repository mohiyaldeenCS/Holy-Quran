import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart' show Curves, TextField;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/ui/core/reader/reader_block.dart';
import 'package:holyquran/ui/core/reader/target_geometry.dart';
import 'package:holyquran/ui/core/widgets/ayah_row.dart';
import 'package:holyquran/ui/core/widgets/ayah_toolbar.dart';
import 'package:holyquran/ui/core/widgets/icon_button.dart' as identity;
import 'package:holyquran/ui/core/widgets/quran_text.dart';
import 'package:holyquran/ui/core/widgets/search_result.dart';
import 'package:holyquran/ui/core/widgets/word_sheet.dart';
import 'package:holyquran/ui/features/mushaf/views/mushaf_screen.dart';
import 'package:holyquran/ui/features/search/views/pinned_controls.dart';
import 'package:holyquran/ui/features/sheets/views/ayah_sheet_view.dart';

import '../../testing/packs/synthetic_files.dart' show syntheticArabic;
import 'frame_stats.dart';
import 'perf_app.dart';
import 'perf_launch.dart';
import 'perf_pack.dart';
import 'perf_result.dart';
import 'perf_run.dart';

/// The engine reports frame timings in batches, up to a second late.
const _timingsBatch = Duration(milliseconds: 1500);

/// The ayah the reader opens at: the middle of the longest surah, so that a
/// start has to scroll to it.
QuranAddress middleOfLongSurah(PerfPackSize size) =>
    QuranAddress('hafs', perfLongSurah, size.longAyat ~/ 2);

/// `NF-01`: from the first frame of the app to the reader showing the saved
/// ayah in its viewport (some of its rectangle inside).
Future<PerfResult> coldStart(
  WidgetTester tester,
  PerfApp perf, {
  required QuranAddress saved,
}) async {
  final launched = await launch(
    tester,
    perf,
    showing: saved,
    leaveSavedAt: middleOfLongSurah(perf.size),
  );
  final shown = launched.reader(tester).position?.address;
  final marks = launched.marks;
  // Scrolling and the sheets leave other positions; each launch leaves the one
  // the next process needs, also when it fails.
  await launched.close(tester);
  // A time to a reader that opened somewhere else is not the budget's.
  expect(shown, saved, reason: 'the reader opens at the saved ayah');
  return resultOf(
    tester,
    'cold_start',
    {
      'savedAyahShownMs': marks.readerShownMs,
      'splashMs': marks.splashMs,
      'dependenciesMs': marks.dependenciesMs,
    },
    {
      'prepared': !perf.packReused,
      'packSize': perf.size.name,
      'saved': '$saved',
      'shown': '$shown',
    },
  );
}

/// `NF-02`: the longest surah in surah mode scrolled at [pixelsPerSecond] for
/// [span], one frame after the other.
Future<PerfResult> scroll(
  WidgetTester tester,
  PerfApp perf, {
  double pixelsPerSecond = 1500,
  Duration span = const Duration(seconds: 10),
}) async {
  final launched = await launch(
    tester,
    perf,
    leaveSavedAt: middleOfLongSurah(perf.size),
  );
  final position = tester
      .state<ScrollableState>(
        find
            .descendant(
              of: find.byType(MushafScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      )
      .position;
  if (isLiveBinding(tester)) {
    // Timings of the start-up's frames, and of the last run's, arrive in
    // batches up to a second late and must not be taken for the scroll's.
    await tester.runAsync(() => Future<void>.delayed(_timingsBatch));
  }
  final recorder = FrameRecorder(engineTimings: isLiveBinding(tester))..start();
  final clock = Stopwatch()..start();
  final travelled = position.pixels;
  final requested = pixelsPerSecond * span.inMicroseconds / 1e6;
  unawaited(
    position.animateTo(
      math.min(position.maxScrollExtent, travelled + requested),
      duration: span,
      curve: Curves.linear,
    ),
  );
  if (isLiveBinding(tester)) {
    // By default the live binding draws only the frames a pump asks for, which
    // would leave the scroll's animation to a handful of them.
    final binding = tester.binding as LiveTestWidgetsFlutterBinding;
    final policy = binding.framePolicy;
    binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
    try {
      await tester.pump(span);
    } finally {
      binding.framePolicy = policy;
    }
  } else {
    const frame = Duration(microseconds: 16667);
    for (var at = Duration.zero; at < span; at += frame) {
      final started = clock.elapsedMicroseconds;
      final cost = Stopwatch()..start();
      await tester.pump(frame);
      recorder.addPumped(started, cost.elapsed);
    }
  }
  await tester.runAsync(() => Future<void>.delayed(_timingsBatch));
  recorder.stop();
  final distance = position.pixels - travelled;
  final extent = position.maxScrollExtent;
  // A surah that ends before the span does would score the frames of a
  // stopped list; the share lets the check refuse such a run.
  final metrics = {
    ...summariseFrames(recorder.frames),
    'travelledShare': distance / requested,
  };
  await launched.close(tester);
  return resultOf(tester, 'scroll', metrics, {
    'prepared': !perf.packReused,
    'frameSource': recorder.source,
    'pixelsPerSecond': pixelsPerSecond,
    'travelledPx': distance,
    'extentPx': extent,
    'spanMs': millis(span),
    'surah': perfLongSurah,
  });
}

/// The query text that matches the stored search form of one word of the
/// synthetic pack (`testing/packs/synthetic_search_forms.dart`).
String searchQueryFor(String kind, QuranAddress word) =>
    '$syntheticArabic $kind ${word.surah}:${word.ayah}:${word.word}';

/// Makes the test text input answer the field, as a plain widget test has it.
/// The integration test binding leaves it off, and then `enterText` and
/// `receiveAction` send messages for client -1, which a profile or release
/// build drops: the field stays empty. It is registered before the app starts
/// so that the field's connection is made with it.
void useTestTextInput(WidgetTester tester) {
  final input = tester.testTextInput;
  if (input.isRegistered) return;
  input.register();
  addTearDown(input.unregister);
}

/// `NF-03`: a query submitted on the search screen to the first result card.
/// Opening the screen builds the index, as the first search of a session
/// does; the time until the field accepts text is reported beside the
/// queries, as `screenReadyMs`.
Future<List<PerfResult>> search(
  WidgetTester tester,
  PerfApp perf, {
  required String first,
  required String second,
}) async {
  useTestTextInput(tester);
  final launched = await launch(
    tester,
    perf,
    leaveSavedAt: middleOfLongSurah(perf.size),
  );
  final opening = Stopwatch()..start();
  launched.router(tester).go(Routes.search);
  final ready = await pumpUntilFrame(
    tester,
    opening,
    () => find.byType(PinnedControls).evaluate().isNotEmpty,
  );
  Future<double> query(String text) async {
    // Emptying the field takes the earlier results away.
    await tester.enterText(find.byType(TextField).first, '');
    await tester.pump();
    expect(find.byType(SearchResult), findsNothing);
    await tester.enterText(find.byType(TextField).first, text);
    final clock = Stopwatch()..start();
    await tester.testTextInput.receiveAction(TextInputAction.search);
    final shown = await pumpUntilFrame(
      tester,
      clock,
      () => find.byType(SearchResult).evaluate().isNotEmpty,
    );
    return millis(shown);
  }

  final cold = await query(first);
  final warm = await query(second);
  await launched.close(tester);
  final prepared = {'prepared': !perf.packReused};
  return [
    resultOf(tester, 'search', {
      'resultsShownMs': cold,
      'screenReadyMs': millis(ready),
    }, prepared),
    resultOf(tester, 'search_warm', {'resultsShownMs': warm}, prepared),
  ];
}

/// The height under which a word is covered by the toolbar that a selected
/// ayah brings up, and by the footer and the player bar.
const _bottomClearance = 160;

/// The first word of the reader that is on the screen, at its centre.
Offset firstWordPoint(WidgetTester tester) {
  final block = find.byType(ReaderBlock).first;
  final layout = tester.widget<ReaderBlock>(block).layout;
  final origin = tester.getTopLeft(block);
  final height = screenRect(tester).height;
  final rect = TargetGeometry.of(layout).words.values
      .firstWhere((r) => (origin + r.center).dy < height - _bottomClearance);
  return origin + rect.center;
}

/// What one opening of a sheet took, from the tap that asked for it.
typedef SheetOpening = ({double visibleMs, double settledMs});

/// Pumps frames until [content], drawn by a sheet, has some of itself inside
/// the screen (its slide-in has begun, so it can be seen and hit), then until
/// it stops moving. A sheet whose widget exists while it is still off the
/// screen is not open.
Future<SheetOpening> timeSheet(
  WidgetTester tester,
  Stopwatch clock,
  Finder content,
) async {
  final screen = screenRect(tester);
  final visible = await pumpUntilFrame(
    tester,
    clock,
    () =>
        content.evaluate().isNotEmpty &&
        screen.overlaps(tester.getRect(content.first)),
  );
  Rect? before;
  final settled = await pumpUntilFrame(tester, clock, () {
    final now = tester.getRect(content.first);
    final still = now == before;
    before = now;
    return still;
  });
  return (visibleMs: millis(visible), settledMs: millis(settled));
}

/// `NF-05`: [repetitions] openings of the word sheet and of the mini ayah
/// sheet, each from the tap that asks for it to the first frame in which the
/// sheet's text is on the screen. The median is the metric, the worst is kept
/// beside it, and the time to the end of the slide is reported as
/// `sheetSettledMs`.
Future<List<PerfResult>> sheets(
  WidgetTester tester,
  PerfApp perf, {
  int repetitions = 10,
}) async {
  final launched = await launch(
    tester,
    perf,
    leaveSavedAt: middleOfLongSurah(perf.size),
  );
  final router = launched.router(tester);
  final l10n = lookupAppLocalizations(const Locale('ar'));
  final reader = launched.reader(tester);

  Future<void> closeSheet() async {
    router.pop();
    await tester.pumpAndSettle();
  }

  final word = <SheetOpening>[];
  final ayah = <SheetOpening>[];
  for (var i = 0; i < repetitions; i++) {
    final clock = Stopwatch()..start();
    await tester.tapAt(firstWordPoint(tester));
    word.add(
      await timeSheet(
        tester,
        clock,
        find.descendant(
          of: find.byType(WordSheet),
          matching: find.byType(QuranText),
        ),
      ),
    );
    await closeSheet();

    await tester.longPressAt(firstWordPoint(tester));
    await tester.pumpAndSettle();
    final study = find.byWidgetPredicate(
      (widget) =>
          widget is identity.IconButton && widget.label == l10n.toolbarStudy,
    );
    expect(find.byType(AyahToolbar), findsOneWidget);
    clock
      ..reset()
      ..start();
    await tester.tap(study);
    ayah.add(
      await timeSheet(
        tester,
        clock,
        find.descendant(
          of: find.byType(AyahSheetView),
          matching: find.byType(AyahRow),
        ),
      ),
    );
    await closeSheet();
    reader.clearSelection();
    await tester.pumpAndSettle();
  }
  await launched.close(tester);
  return [
    _sheetResult(tester, perf, 'word_sheet', word),
    _sheetResult(tester, perf, 'ayah_sheet', ayah),
  ];
}

double _median(List<double> values) {
  final sorted = [...values]..sort();
  final middle = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[middle]
      : (sorted[middle - 1] + sorted[middle]) / 2;
}

PerfResult _sheetResult(
  WidgetTester tester,
  PerfApp perf,
  String scenario,
  List<SheetOpening> openings,
) {
  final visible = [for (final opening in openings) opening.visibleMs];
  return resultOf(
    tester,
    scenario,
    {
      'sheetOpenMs': _median(visible),
      'sheetOpenWorstMs': visible.reduce(math.max),
      'sheetSettledMs': _median([
        for (final opening in openings) opening.settledMs,
      ]),
    },
    {'repetitions': openings.length, 'prepared': !perf.packReused},
  );
}
