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

  bool holds(num value) => comparison.holds(value, limit);

  @override
  String toString() => '$id $scenario.$metric ${comparison.words} $limit $unit';
}

const _prd = 'PRD §11';

/// The budgets the harness measures (`docs/ARCHITECTURE.md`, "Budgets"), on
/// the two reference devices of Phase 0. `NF-04` and `NF-09` need a recitation
/// and the player, which a harness over a synthetic text pack does not have.
const List<PerfCheck> perfChecks = [
  PerfCheck(
    id: 'NF-01',
    scenario: 'cold_start',
    metric: 'savedAyahShownMs',
    comparison: Comparison.atMost,
    limit: 2000,
    unit: 'ms',
    source: '$_prd, NF-01: cold start to the last reading position, 2 s',
    measures:
        'From the start of the app (before its dependencies are built) to '
        'the first frame in which the reader shows the saved ayah.',
  ),
  PerfCheck(
    id: 'NF-02',
    scenario: 'scroll',
    metric: 'framesPerSecond',
    comparison: Comparison.atLeast,
    limit: 59,
    unit: 'fps',
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
    metric: 'p99FrameMs',
    comparison: Comparison.atMost,
    limit: 32,
    unit: 'ms',
    source: '$_prd, NF-02: 99% of frames under 32 ms',
    measures:
        'The 99th percentile of the frame total (vsync to raster end) over '
        'the same scroll.',
  ),
  PerfCheck(
    id: 'NF-02',
    scenario: 'scroll',
    metric: 'travelledShare',
    comparison: Comparison.atLeast,
    limit: 0.95,
    unit: 'of the span',
    source:
        'The harness: frames are only those of a scroll if the list moved '
        'for the whole span',
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
    source: '$_prd, NF-03: offline text search results, 300 ms',
    measures:
        'From submitting the first query on the search screen to the first '
        'frame showing a result. The index is built when the screen opens; '
        'that time is reported beside it as screenReadyMs.',
  ),
  PerfCheck(
    id: 'NF-03',
    scenario: 'search_warm',
    metric: 'resultsShownMs',
    comparison: Comparison.atMost,
    limit: 300,
    unit: 'ms',
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
    source: '$_prd, NF-05: word or ayah sheet opens, 200 ms',
    measures:
        'From tapping a word in the reader to the first frame in which the '
        'word sheet shows its word.',
  ),
  PerfCheck(
    id: 'NF-05',
    scenario: 'ayah_sheet',
    metric: 'sheetOpenMs',
    comparison: Comparison.atMost,
    limit: 200,
    unit: 'ms',
    source: '$_prd, NF-05: word or ayah sheet opens, 200 ms',
    measures:
        'From pressing the study button of the toolbar to the first frame in '
        'which the mini ayah sheet shows its ayah.',
  ),
];

/// The scenarios the checks name, in the order the harness runs them.
List<String> get perfScenarios => [
  ...{for (final check in perfChecks) check.scenario},
];
