import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/ui/features/search/view_models/search_view_model.dart';

import '../../integration_test/perf/perf_app.dart';
import '../../integration_test/perf/perf_launch.dart';
import '../../integration_test/perf/perf_pack.dart';
import '../../integration_test/perf/perf_result.dart';
import '../../integration_test/perf/perf_scenarios.dart' as scenarios;

// The scenarios of the harness on a small pack, so that they keep working with
// the app between runs on a device. Their numbers say nothing: a debug build
// on a computer, with frames that are never drawn. `--dart-define=PERF_SIZE=full`
// runs them on the full pack, which gives informative figures.
const _size = String.fromEnvironment('PERF_SIZE') == 'full'
    ? PerfPackSize.full
    : PerfPackSize.small;

void main() {
  final results = <PerfResult>[];
  // A line per result, as the harness prints them on a device.
  tearDownAll(() => results.map((r) => r.toLogLine()).forEach(debugPrint));

  Future<PerfApp> prepare(WidgetTester tester, QuranAddress seed) =>
      preparePerfApp(tester, size: _size, seed: seed, reseed: true);

  testWidgets('a cold start shows the saved ayah', (tester) async {
    final saved = scenarios.middleOfLongSurah(_size);
    final perf = await prepare(tester, saved);

    final result = await scenarios.coldStart(tester, perf, saved: saved);
    results.add(result);

    expect(result.scenario, 'cold_start');
    expect(result.metrics['savedAyahShownMs'], greaterThan(0));
    expect(
      result.metrics['savedAyahShownMs'],
      greaterThanOrEqualTo(result.metrics['dependenciesMs']!),
    );
    expect(result.details['shown'], '$saved');
    expect(result.details['prepared'], isTrue);
    expect(result.comparable, isFalse, reason: 'a debug build');
  });

  testWidgets('the cold start ends with the saved ayah inside the viewport', (
    tester,
  ) async {
    final saved = scenarios.middleOfLongSurah(_size);
    final perf = await prepare(tester, saved);

    final launched = await launch(tester, perf, showing: saved);

    expect(ayahInViewport(tester, saved), isTrue);
    expect(
      ayahInViewport(tester, QuranAddress('hafs', perfLongSurah, 1)),
      isFalse,
      reason: 'the top of the surah was scrolled away',
    );
    await launched.close(tester);
  });

  testWidgets('a cold start finds its position after a scroll and the sheets', (
    tester,
  ) async {
    final saved = scenarios.middleOfLongSurah(_size);
    final perf = await prepare(tester, QuranAddress('hafs', perfLongSurah, 1));

    await scenarios.sheets(tester, perf, repetitions: 1);
    final afterSheets = await scenarios.coldStart(tester, perf, saved: saved);
    await scenarios.scroll(tester, perf, span: const Duration(seconds: 1));
    final afterScroll = await scenarios.coldStart(tester, perf, saved: saved);
    final again = await scenarios.coldStart(tester, perf, saved: saved);

    for (final result in [afterScroll, afterSheets, again]) {
      expect(result.details['shown'], '$saved');
    }
  });

  testWidgets('a scroll records frames and moves the reader', (tester) async {
    final perf = await prepare(tester, QuranAddress('hafs', perfLongSurah, 1));

    final result = await scenarios.scroll(
      tester,
      perf,
      span: const Duration(seconds: 2),
    );
    results.add(result);

    expect(result.metrics['frames'], greaterThan(60));
    expect(result.metrics['framesPerSecond'], greaterThan(0));
    expect(result.metrics['p99FrameMs'], greaterThan(0));
    expect(result.details['frameSource'], 'pump-wall-clock');
    expect(result.details['prepared'], isTrue);
    // The small pack's surah is shorter than the 3000 px the span asks for.
    expect(
      result.details['travelledPx'],
      allOf(greaterThan(0), lessThan(3001)),
    );
    expect(
      result.metrics['travelledShare'],
      allOf(greaterThan(0), lessThan(1.01)),
    );
  });

  testWidgets('a search finds the word of its query and times both queries', (
    tester,
  ) async {
    final perf = await prepare(tester, QuranAddress('hafs', 1, 1));

    final found = await scenarios.search(
      tester,
      perf,
      first: scenarios.searchQueryFor(
        SearchKinds.word,
        QuranAddress('hafs', 1, 2, 1),
      ),
      second: scenarios.searchQueryFor(
        SearchKinds.word,
        QuranAddress('hafs', 3, 3, 1),
      ),
    );
    results.addAll(found);

    expect([for (final r in found) r.scenario], ['search', 'search_warm']);
    for (final result in found) {
      expect(result.metrics['resultsShownMs'], greaterThan(0));
    }
  });

  testWidgets('a search registers the test text input itself', (tester) async {
    // As under the integration test binding, which does not register it.
    tester.testTextInput.unregister();
    expect(tester.testTextInput.isRegistered, isFalse);
    final perf = await prepare(tester, QuranAddress('hafs', 1, 1));

    final found = await scenarios.search(
      tester,
      perf,
      first: scenarios.searchQueryFor(
        SearchKinds.word,
        QuranAddress('hafs', 1, 2, 1),
      ),
      second: scenarios.searchQueryFor(
        SearchKinds.word,
        QuranAddress('hafs', 3, 3, 1),
      ),
    );

    expect(found, hasLength(2));
    expect(tester.testTextInput.isRegistered, isTrue);
  });

  testWidgets('the test text input is registered once and left as found', (
    tester,
  ) async {
    scenarios.useTestTextInput(tester);
    expect(tester.testTextInput.isRegistered, isTrue);

    tester.testTextInput.unregister();
    scenarios.useTestTextInput(tester);

    expect(tester.testTextInput.isRegistered, isTrue);
  });

  testWidgets('the sheets open from the reader and are timed each time', (
    tester,
  ) async {
    final perf = await prepare(tester, QuranAddress('hafs', perfLongSurah, 1));

    final opened = await scenarios.sheets(tester, perf, repetitions: 2);
    results.addAll(opened);

    expect([for (final r in opened) r.scenario], ['word_sheet', 'ayah_sheet']);
    for (final result in opened) {
      expect(result.metrics['sheetOpenMs'], greaterThan(0));
      expect(
        result.metrics['sheetOpenWorstMs'],
        greaterThanOrEqualTo(result.metrics['sheetOpenMs']!),
      );
      expect(result.details['repetitions'], 2);
      expect(result.details['prepared'], isTrue);
      expect(result.metrics['sheetSettledMs'], greaterThan(0));
    }
  });

  testWidgets('a sheet is open when it is on the screen, not when it exists', (
    tester,
  ) async {
    // Off the screen until the last 15% of a one-second slide.
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.rtl,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(seconds: 1),
          builder: (context, progress, child) => Transform.translate(
            offset: Offset(
              0,
              2000 * (1 - ((progress - 0.5) / 0.5).clamp(0, 1)),
            ),
            child: child,
          ),
          child: const SizedBox(key: Key('sheet'), width: 100, height: 100),
        ),
      ),
    );

    final opening = await scenarios.timeSheet(
      tester,
      Stopwatch()..start(),
      find.byKey(const Key('sheet')),
    );

    // Each frame costs at least a millisecond of real time and 2 ms of the
    // animation's: reaching 85% takes over 400 frames.
    expect(opening.visibleMs, greaterThan(400));
    expect(opening.settledMs, greaterThan(opening.visibleMs));
  });
}
