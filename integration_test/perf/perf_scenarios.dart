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

/// The ayah the reader opens at: the middle of the longest surah, so that a
/// start has to scroll to it.
QuranAddress middleOfLongSurah(PerfPackSize size) =>
    QuranAddress('hafs', perfLongSurah, size.longAyat ~/ 2);

/// `NF-01`: from the start of the app to the reader showing the saved ayah.
Future<PerfResult> coldStart(
  WidgetTester tester,
  PerfApp perf, {
  required QuranAddress saved,
}) async {
  final launched = await launch(tester, perf, scrolled: true);
  final shown = launched.reader(tester).position?.address;
  final marks = launched.marks;
  await launched.close(tester);
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
  final launched = await launch(tester, perf, scrolled: false);
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
  // The engine reports frame timings in batches, up to a second late.
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 1500)),
  );
  recorder.stop();
  final distance = position.pixels - travelled;
  // A surah that ends before the span does would score the frames of a
  // stopped list; the share lets the check refuse such a run.
  final metrics = {
    ...summariseFrames(recorder.frames),
    'travelledShare': distance / requested,
  };
  await launched.close(tester);
  return resultOf(tester, 'scroll', metrics, {
    'frameSource': recorder.source,
    'pixelsPerSecond': pixelsPerSecond,
    'travelledPx': distance,
    'spanMs': millis(span),
    'surah': perfLongSurah,
  });
}

/// The query text that matches the stored search form of one word of the
/// synthetic pack (`testing/packs/synthetic_search_forms.dart`).
String searchQueryFor(String kind, QuranAddress word) =>
    '$syntheticArabic $kind ${word.surah}:${word.ayah}:${word.word}';

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
  final launched = await launch(tester, perf, scrolled: false);
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

/// The first word of the reader that is on the screen, at its centre.
Offset firstWordPoint(WidgetTester tester) {
  final block = find.byType(ReaderBlock).first;
  final layout = tester.widget<ReaderBlock>(block).layout;
  final origin = tester.getTopLeft(block);
  final height = tester.view.physicalSize.height / tester.view.devicePixelRatio;
  final rect = TargetGeometry.of(layout).words.values
      .firstWhere((r) => (origin + r.center).dy < height - 160);
  return origin + rect.center;
}

/// `NF-05`: [repetitions] openings of the word sheet and of the mini ayah
/// sheet, each from the tap that asks for it to the first frame that draws
/// its text. The median is the metric; the worst is kept beside it.
Future<List<PerfResult>> sheets(
  WidgetTester tester,
  PerfApp perf, {
  int repetitions = 10,
}) async {
  final launched = await launch(tester, perf, scrolled: false);
  final router = launched.router(tester);
  final l10n = lookupAppLocalizations(const Locale('ar'));
  final reader = launched.reader(tester);

  Future<void> closeSheet() async {
    router.pop();
    await tester.pumpAndSettle();
  }

  final word = <double>[];
  final ayah = <double>[];
  for (var i = 0; i < repetitions; i++) {
    final clock = Stopwatch()..start();
    await tester.tapAt(firstWordPoint(tester));
    word.add(
      millis(
        await pumpUntilFrame(
          tester,
          clock,
          () => find
              .descendant(
                of: find.byType(WordSheet),
                matching: find.byType(QuranText),
              )
              .evaluate()
              .isNotEmpty,
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
      millis(
        await pumpUntilFrame(
          tester,
          clock,
          () => find
              .descendant(
                of: find.byType(AyahSheetView),
                matching: find.byType(AyahRow),
              )
              .evaluate()
              .isNotEmpty,
        ),
      ),
    );
    await closeSheet();
    reader.clearSelection();
    await tester.pumpAndSettle();
  }
  await launched.close(tester);
  return [
    _sheetResult(tester, 'word_sheet', word),
    _sheetResult(tester, 'ayah_sheet', ayah),
  ];
}

PerfResult _sheetResult(WidgetTester tester, String scenario, List<double> ms) {
  final sorted = [...ms]..sort();
  return resultOf(
    tester,
    scenario,
    {
      'sheetOpenMs': sorted[sorted.length ~/ 2],
      'sheetOpenWorstMs': sorted.last,
    },
    {'repetitions': ms.length},
  );
}
