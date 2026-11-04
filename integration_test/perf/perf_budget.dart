/// How a measured value is held against a limit.
enum Comparison {
  atMost('at most'),
  atLeast('at least');

  const Comparison(this.words);

  final String words;

  bool holds(num value, num limit) => switch (this) {
    atMost => value <= limit,
    atLeast => value >= limit,
  };
}

/// One number a budget is judged by: [metric] of [scenario]'s result, held
/// against [limit].
final class PerfCheck {
  const PerfCheck({
    required this.id,
    required this.scenario,
    required this.metric,
    required this.comparison,
    required this.limit,
    required this.unit,
    required this.source,
    required this.measures,
    required this.minSamples,
    this.everyRun = false,
  });

  /// The PRD requirement (`NF-01`).
  final String id;
  final String scenario;
  final String metric;
  final Comparison comparison;
  final num limit;
  final String unit;

  /// Where the number comes from.
  final String source;

  /// What the harness times to get the metric, in words.
  final String measures;

  /// How many measurements the device protocol asks for
  /// (`integration_test/perf/README.md`): ten cold starts, five searches,
  /// three scrolls, ten openings of each sheet. A verdict from fewer is
  /// incomplete, not met.
  final int minSamples;

  /// Whether every run must hold, not just the median: for a validity check,
  /// where one bad run among good ones is a bad run.
  final bool everyRun;

  bool holds(num value) => comparison.holds(value, limit);

  @override
  String toString() => '$id $scenario.$metric ${comparison.words} $limit $unit';
}

const _prd = 'PRD §11';

/// The budgets the harness measures (`docs/ARCHITECTURE.md`, "Budgets"), on
/// the two reference devices of Phase 0. `NF-04` and `NF-09` need a recitation
/// and the player, which a harness over a synthetic text pack does not have;
/// `NF-02`'s page turning is not measured either (D-157).
const List<PerfCheck> perfChecks = [
  PerfCheck(
    id: 'NF-01',
    scenario: 'cold_start',
    metric: 'savedAyahShownMs',
    comparison: Comparison.atMost,
    limit: 2000,
    unit: 'ms',
    minSamples: 10,
    source: '$_prd, NF-01: cold start to the last reading position, 2 s',
    measures:
        'A stand-in for the product\'s figure: from the first frame of the '
        'app (the splash, before its dependencies are built) to the first '
        'frame in which the saved ayah\'s rectangle is inside the reader\'s '
        'viewport. The engine\'s start-up before Dart runs, and the audio, '
        'download, catalogue and tafsir areas of the real start-up, are not '
        'in the figure.',
  ),
  PerfCheck(
    id: 'NF-02',
    scenario: 'scroll',
    metric: 'framesPerSecond',
    comparison: Comparison.atLeast,
    limit: 59,
    unit: 'fps',
    minSamples: 3,
    source:
        '$_prd, NF-02: 60 frames per second; one frame per second of '
        'tolerance covers the rounding of a rate counted from vsync times '
        '(D-157)',
    measures:
        'Frames per second over the scroll of the longest surah in surah '
        'mode at 1500 px/s.',
  ),
  PerfCheck(
    id: 'NF-02',
    scenario: 'scroll',
    metric: 'over32MsShare',
    comparison: Comparison.atMost,
    limit: 0.01,
    unit: 'of frames',
    minSamples: 3,
    source: '$_prd, NF-02: 99% of frames under 32 ms',
    measures:
        'The share of frames whose total (vsync to raster end) is over 32 ms, '
        'over the same scroll: at most 1% means 99% are not over.',
  ),
  PerfCheck(
    id: 'NF-02',
    scenario: 'scroll',
    metric: 'travelledShare',
    comparison: Comparison.atLeast,
    limit: 0.95,
    everyRun: true,
    unit: 'of the span',
    minSamples: 3,
    source:
        'NF-02, harness validity: frames are only those of a scroll if the '
        'list moved for the whole span',
    measures:
        'The distance the list moved, over the distance 1500 px/s asks for. '
        'Below the limit the longest surah is too short for the span.',
  ),
  PerfCheck(
    id: 'NF-03',
    scenario: 'search',
    metric: 'resultsShownMs',
    comparison: Comparison.atMost,
    limit: 300,
    unit: 'ms',
    minSamples: 5,
    source: '$_prd, NF-03: offline text search results, 300 ms',
    measures:
        'From submitting the first query on the search screen to the first '
        'frame showing a result. The index is built when the screen opens; '
        'that time is reported beside it as screenReadyMs and is not '
        'budgeted.',
  ),
  PerfCheck(
    id: 'NF-03',
    scenario: 'search_warm',
    metric: 'resultsShownMs',
    comparison: Comparison.atMost,
    limit: 300,
    unit: 'ms',
    minSamples: 5,
    source: '$_prd, NF-03: offline text search results, 300 ms',
    measures: 'The same, for the second query of the same screen.',
  ),
  PerfCheck(
    id: 'NF-05',
    scenario: 'word_sheet',
    metric: 'sheetOpenMs',
    comparison: Comparison.atMost,
    limit: 200,
    unit: 'ms',
    minSamples: 10,
    source: '$_prd, NF-05: word or ayah sheet opens, 200 ms',
    measures:
        'From tapping a word in the reader to the first frame in which the '
        'sheet\'s word is on the screen (the slide-in has begun). The time '
        'to the end of the slide is reported beside it as sheetSettledMs.',
  ),
  PerfCheck(
    id: 'NF-05',
    scenario: 'ayah_sheet',
    metric: 'sheetOpenMs',
    comparison: Comparison.atMost,
    limit: 200,
    unit: 'ms',
    minSamples: 10,
    source: '$_prd, NF-05: word or ayah sheet opens, 200 ms',
    measures:
        'From pressing the study button of the toolbar to the first frame in '
        'which the mini ayah sheet\'s ayah is on the screen. The time to the '
        'end of the slide is reported beside it as sheetSettledMs.',
  ),
];
