import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/edition_map.dart';
import 'package:holyquran/domain/models/playback_plan.dart';
import 'package:holyquran/domain/models/playback_plan_builder.dart';
import 'package:holyquran/domain/models/playback_range.dart';
import 'package:holyquran/domain/models/playback_segment.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/quran_range.dart';
import 'package:holyquran/domain/models/recitation.dart';
import 'package:holyquran/domain/models/repeat_mode.dart';

QuranAddress _a(String source) => QuranAddress.parse('x:$source');

List<QuranAddress> _as(String sources) =>
    sources.split(' ').map(_a).toList(growable: false);

/// A synthetic edition: ten surahs whose counts are not the Quran's.
/// Page 4 runs across the end of surah 2; surahs 1 and 9 have no separate
/// basmala.
const _ayahCounts = [4, 12, 5, 4, 6, 3, 8, 2, 9, 4];
const _basmalaSurahs = {2, 3, 4, 5, 6, 7, 8, 10};
final _edition = EditionMap(
  edition: 'synthetic',
  starts: {
    Division.page: _as('1:1 2:1 2:6 2:11 3:3 4:1 5:4 7:1 8:2 9:6 10:1'),
    Division.juz: _as('1:1 2:9 5:2 9:1'),
    Division.hizb: _as('1:1 2:4 2:9 3:4 5:2 7:3 9:1 10:2'),
  },
  sajdas: const {},
);

final _builder = PlaybackPlanBuilder(
  edition: _edition,
  ayahCounts: _ayahCounts,
  basmalaSurahs: _basmalaSurahs,
);

Recitation _recitation({
  RecitationUnit unit = RecitationUnit.ayah,
  bool rightsComplete = true,
  bool basmala = false,
  bool istiadha = false,
  String riwaya = 'x',
}) => Recitation(
  id: 'synthetic-${unit.name}',
  reciter: 'Reciter A',
  riwaya: riwaya,
  style: 'Style A',
  unit: unit,
  hasWordTiming: false,
  rightsComplete: rightsComplete,
  hasBasmalaFile: basmala,
  hasIstiadhaFile: istiadha,
);

PlaybackPlan _plan(
  PlaybackRange range, {
  Recitation? recitation,
  RepeatMode repeat = RepeatMode.once,
  Duration silence = Duration.zero,
  bool continueToNextSurah = false,
  AyahTimings? timings,
}) => switch (_builder.build(
  recitation ?? _recitation(),
  range,
  repeat: repeat,
  silence: silence,
  continueToNextSurah: continueToNextSurah,
  timings: timings,
)) {
  PlanReady(:final plan) => plan,
  PlanRefused(:final reason) => fail('refused: $reason'),
};

PlanRefusal? _refusal(
  PlaybackRange range, {
  required Recitation recitation,
  RepeatMode repeat = RepeatMode.once,
}) => switch (_builder.build(recitation, range, repeat: repeat)) {
  PlanReady() => null,
  PlanRefused(:final reason) => reason,
};

List<String> _ayat(PlaybackRange range) =>
    _builder.ayatOf(range).map((a) => '${a.surah}:${a.ayah}').toList();

/// Each segment as `kind surah:ayah #repeat`.
List<String> _brief(Iterable<PlaybackSegment> segments) => [
  for (final s in segments)
    '${s.kind.name} ${s.address.surah}:${s.address.ayah} #${s.repeat}',
];

List<String> _span(String from, String to) =>
    _ayat(AyahSpan(QuranRange(_a(from), _a(to))));

/// Synthetic timing: ayah n of a surah from n seconds to n + 1, the basmala
/// in the first second, except in surahs listed as untimed.
final class _FakeTimings implements AyahTimings {
  const _FakeTimings({this.noBasmala = const {}});

  final Set<int> noBasmala;

  @override
  SurahClip clipOf(QuranAddress ayah) => SurahClip(
    ayah.surah,
    Duration(seconds: ayah.ayah),
    Duration(seconds: ayah.ayah + 1),
  );

  @override
  SurahClip? basmalaOf(int surah) => noBasmala.contains(surah)
      ? null
      : SurahClip(surah, Duration.zero, const Duration(seconds: 1));
}

void main() {
  group('ranges resolve to exact ayah boundaries (AU-02, AU-03)', () {
    test('an ayah and an ayah range', () {
      expect(_ayat(SingleAyah(_a('2:5'))), ['2:5']);
      expect(_span('2:11', '3:2'), ['2:11', '2:12', '3:1', '3:2']);
    });

    test('the current page, several pages, the last page', () {
      expect(_ayat(PageSpan(4)), _span('2:11', '3:2'));
      expect(_ayat(PageSpan(4, 5)), _span('2:11', '3:5'));
      expect(_ayat(PageSpan(1)), _span('1:1', '1:4'));
      expect(_ayat(PageSpan(11)), _span('10:1', '10:4'));
    });

    test('a surah, a juz and a hizb', () {
      expect(_ayat(WholeSurah(3)), _span('3:1', '3:5'));
      expect(_ayat(WholeSurah(10)), _span('10:1', '10:4'));
      expect(_ayat(WholeJuz(2)), _span('2:9', '5:1'));
      expect(_ayat(WholeJuz(4)), _span('9:1', '10:4'));
      expect(_ayat(WholeHizb(4)), _span('3:4', '5:1'));
      expect(_ayat(WholeHizb(8)), _span('10:2', '10:4'));
    });

    test('a set of surahs plays in mushaf order, each once', () {
      expect(_ayat(SurahSet([7, 3, 7])), [
        ..._span('3:1', '3:5'),
        ..._span('7:1', '7:8'),
      ]);
    });

    test('from here to the end of the mushaf', () {
      expect(_ayat(ToEndOfMushaf(_a('9:8'))), [
        '9:8',
        '9:9',
        ..._span('10:1', '10:4'),
      ]);
    });

    test('the ayah tools', () {
      List<String> tool(AyahToolEnd until) =>
          _ayat(FromAyahTool(_a('2:12'), until));
      expect(tool(AyahToolEnd.ayah), ['2:12']);
      expect(tool(AyahToolEnd.page), _span('2:12', '3:2'));
      expect(tool(AyahToolEnd.surah), ['2:12']);
      expect(tool(AyahToolEnd.juz), _span('2:12', '5:1'));
      expect(tool(AyahToolEnd.untilStopped), _span('2:12', '10:4'));
      expect(
        _ayat(FromAyahTool(_a('10:3'), AyahToolEnd.page)),
        _span('10:3', '10:4'),
      );
      expect(
        _ayat(FromAyahTool(_a('9:8'), AyahToolEnd.juz)),
        ['9:8', '9:9', ..._span('10:1', '10:4')],
        reason: 'the last juz ends with the mushaf',
      );
    });

    test('a number outside the edition is refused, never clamped', () {
      expect(() => _ayat(SingleAyah(_a('2:13'))), throwsRangeError);
      expect(() => _ayat(SingleAyah(_a('11:1'))), throwsRangeError);
      expect(() => _ayat(WholeSurah(11)), throwsRangeError);
      expect(() => _ayat(PageSpan(11, 12)), throwsRangeError);
      expect(() => _ayat(WholeJuz(5)), throwsRangeError);
      expect(() => _ayat(WholeHizb(9)), throwsRangeError);
      expect(
        () => _ayat(SingleAyah(QuranAddress.parse('y:1:1'))),
        throwsArgumentError,
      );
    });
  });

  group('segments', () {
    test('one file per ayah, with page and surah ends from the edition', () {
      final segments = _plan(PageSpan(4)).segments.toList();
      expect(segments.map((s) => s.source), [
        for (final a in _builder.ayatOf(PageSpan(4))) AyahFile(a),
      ]);
      expect(_brief(segments), [
        'ayah 2:11 #1',
        'ayah 2:12 #1',
        'ayah 3:1 #1',
        'ayah 3:2 #1',
      ]);
      expect(segments.map((s) => s.endsSurah), [false, true, false, false]);
      expect(segments.map((s) => s.endsPage), [false, false, false, true]);
      final last = _plan(SingleAyah(_a('10:4'))).segments.single;
      expect(last.endsPage && last.endsSurah, isTrue);
    });

    test('silence follows every ayah but the last (AU-11)', () {
      const silence = Duration(seconds: 3);
      final segments = _plan(
        AyahSpan(QuranRange(_a('2:12'), _a('3:2'))),
        recitation: _recitation(basmala: true, istiadha: true),
        repeat: RepeatMode(RepeatUnit.ayah, 2),
        silence: silence,
      ).segments.toList();
      expect(_brief(segments), [
        'istiadha 2:12 #1',
        'ayah 2:12 #1',
        'ayah 2:12 #2',
        'basmala 3:1 #1',
        'ayah 3:1 #1',
        'ayah 3:1 #2',
        'ayah 3:2 #1',
        'ayah 3:2 #2',
      ]);
      expect(segments.map((s) => s.silenceAfter), [
        Duration.zero,
        silence,
        silence,
        Duration.zero,
        silence,
        silence,
        silence,
        Duration.zero,
      ]);
    });

    test('no silence when none is asked; 30 s at most', () {
      expect(_plan(WholeSurah(3)).segments.map((s) => s.silenceAfter).toSet(), {
        Duration.zero,
      });
      final longest = _plan(
        WholeSurah(3),
        silence: PlaybackPlanBuilder.maxSilence,
      );
      expect(longest.segments.first.silenceAfter, const Duration(seconds: 30));
      for (final wrong in [
        const Duration(seconds: 31),
        const Duration(milliseconds: -1),
      ]) {
        expect(
          () => _builder.build(_recitation(), WholeSurah(3), silence: wrong),
          throwsRangeError,
        );
      }
    });

    test('a recitation without a complete rights record has no plan', () {
      expect(
        _refusal(WholeSurah(3), recitation: _recitation(rightsComplete: false)),
        PlanRefusal.rightsIncomplete,
      );
    });

    test('timing data is refused for a recitation served by ayah files', () {
      expect(
        () => _builder.build(
          _recitation(),
          WholeSurah(3),
          timings: const _FakeTimings(),
        ),
        throwsArgumentError,
      );
    });

    test('the edition and the basmala list are checked when given', () {
      expect(
        () => PlaybackPlanBuilder(
          edition: _edition,
          ayahCounts: _ayahCounts,
          basmalaSurahs: const {11},
        ),
        throwsArgumentError,
      );
      expect(
        () => PlaybackPlanBuilder(
          edition: EditionMap(
            edition: 'synthetic',
            starts: {
              Division.page: _as('1:2 2:1'),
              Division.juz: _as('1:1'),
              Division.hizb: _as('1:1'),
            },
            sajdas: const {},
          ),
          ayahCounts: _ayahCounts,
          basmalaSurahs: _basmalaSurahs,
        ),
        throwsArgumentError,
      );
      expect(
        () => PlaybackPlanBuilder(
          edition: EditionMap(
            edition: 'synthetic',
            starts: {Division.page: _as('1:1')},
            sajdas: const {},
          ),
          ayahCounts: _ayahCounts,
          basmalaSurahs: _basmalaSurahs,
        ),
        throwsArgumentError,
        reason: 'no juz or hizb starts',
      );
    });

    test('a recitation in another riwaya is refused', () {
      expect(
        () => _builder.build(_recitation(riwaya: 'y'), WholeSurah(3)),
        throwsArgumentError,
      );
    });
  });

  group('basmala and isti\'adha only from the recitation (AU-24)', () {
    final withFiles = _recitation(basmala: true, istiadha: true);

    test('a surah opens with the recitation\'s basmala file', () {
      final segments = _plan(
        WholeSurah(3),
        recitation: _recitation(basmala: true),
      ).segments.toList();
      expect(_brief(segments.take(2)), ['basmala 3:1 #1', 'ayah 3:1 #1']);
      expect(segments.first.source, const BasmalaFile());
    });

    test('surah 1 has its basmala as ayah 1, surah 9 has none', () {
      expect(
        _brief(_plan(WholeSurah(1), recitation: withFiles).segments.take(2)),
        ['istiadha 1:1 #1', 'ayah 1:1 #1'],
      );
      expect(
        _brief(_plan(WholeSurah(9), recitation: withFiles).segments.take(2)),
        ['istiadha 9:1 #1', 'ayah 9:1 #1'],
      );
      expect(
        _plan(
              AyahSpan(QuranRange(_a('8:1'), _a('10:1'))),
              recitation: withFiles,
            ).segments
            .where((s) => s.kind == SegmentKind.basmala)
            .map((s) => s.address),
        [_a('8:1'), _a('10:1')],
        reason: 'none before 9:1',
      );
    });

    test('no basmala inside a surah', () {
      expect(
        _brief(_plan(SingleAyah(_a('3:2')), recitation: withFiles).segments),
        ['istiadha 3:2 #1', 'ayah 3:2 #1'],
      );
    });

    test('none is borrowed when the recitation has no such file', () {
      final kinds = _plan(WholeSurah(3)).segments.map((s) => s.kind).toSet();
      expect(kinds, {SegmentKind.ayah});
    });

    test('the isti\'adha opens the plan once, whatever the repeats', () {
      final segments = _plan(
        WholeSurah(3),
        recitation: withFiles,
        repeat: RepeatMode(RepeatUnit.range, 3),
      ).segments.toList();
      expect(segments.first.kind, SegmentKind.istiadha);
      expect(segments.first.source, const IstiadhaFile());
      expect(
        segments.where((s) => s.kind == SegmentKind.istiadha),
        hasLength(1),
      );
      expect(
        segments.where((s) => s.kind == SegmentKind.basmala),
        hasLength(3),
      );
    });

    test('an ayah repeat hears the basmala once, before the first hearing', () {
      expect(
        _brief(
          _plan(
            SingleAyah(_a('3:1')),
            recitation: _recitation(basmala: true),
            repeat: RepeatMode(RepeatUnit.ayah, 3),
          ).segments,
        ),
        ['basmala 3:1 #1', 'ayah 3:1 #1', 'ayah 3:1 #2', 'ayah 3:1 #3'],
      );
    });
  });

  group('repeat n is heard exactly n times (AU-09)', () {
    test('an ayah, for every n from 1 to 99', () {
      for (var n = RepeatMode.minCount; n <= RepeatMode.maxCount; n++) {
        final segments = _plan(
          AyahSpan(QuranRange(_a('2:1'), _a('2:3'))),
          repeat: RepeatMode(RepeatUnit.ayah, n),
        ).segments.toList();
        expect(segments, hasLength(3 * n), reason: 'n = $n');
        for (final (index, ayah) in ['2:1', '2:2', '2:3'].indexed) {
          final run = segments.skip(index * n).take(n);
          expect(run.map((s) => s.address).toSet(), {_a(ayah)});
          expect(run.map((s) => s.repeat), [for (var i = 1; i <= n; i++) i]);
        }
      }
    });

    test('a range, for every n from 1 to 99', () {
      for (var n = RepeatMode.minCount; n <= RepeatMode.maxCount; n++) {
        final segments = _plan(
          AyahSpan(QuranRange(_a('2:1'), _a('2:3'))),
          repeat: RepeatMode(RepeatUnit.range, n),
        ).segments.toList();
        expect(_brief(segments), [
          for (var pass = 1; pass <= n; pass++)
            for (final ayah in ['2:1', '2:2', '2:3']) 'ayah $ayah #$pass',
        ], reason: 'n = $n');
      }
    });

    test('a page, for every n from 1 to 99, its basmala in each pass', () {
      for (var n = RepeatMode.minCount; n <= RepeatMode.maxCount; n++) {
        final segments = _plan(
          PageSpan(4, 5),
          recitation: _recitation(basmala: true),
          repeat: RepeatMode(RepeatUnit.page, n),
        ).segments.toList();
        expect(_brief(segments), [
          for (var pass = 1; pass <= n; pass++) ...[
            'ayah 2:11 #$pass',
            'ayah 2:12 #$pass',
            'basmala 3:1 #1',
            'ayah 3:1 #$pass',
            'ayah 3:2 #$pass',
          ],
          for (var pass = 1; pass <= n; pass++)
            for (final ayah in ['3:3', '3:4', '3:5']) 'ayah $ayah #$pass',
        ], reason: 'n = $n');
      }
    });

    test('a surah, for every n from 1 to 99', () {
      for (var n = RepeatMode.minCount; n <= RepeatMode.maxCount; n++) {
        final segments = _plan(
          SurahSet(const [6, 8]),
          repeat: RepeatMode(RepeatUnit.surah, n),
        ).segments.toList();
        expect(_brief(segments), [
          for (var pass = 1; pass <= n; pass++)
            for (final ayah in ['6:1', '6:2', '6:3']) 'ayah $ayah #$pass',
          for (var pass = 1; pass <= n; pass++)
            for (final ayah in ['8:1', '8:2']) 'ayah $ayah #$pass',
        ], reason: 'n = $n');
      }
    });

    test('unlimited repeat is built lazily and never ends', () {
      final plan = _plan(
        SingleAyah(_a('2:5')),
        repeat: const RepeatMode.unlimited(RepeatUnit.ayah),
        silence: const Duration(seconds: 1),
      );
      final first = plan.segments.take(100000).toList();
      expect(first.map((s) => s.address).toSet(), {_a('2:5')});
      expect(first.last.repeat, 100000);
      expect(first.last.silenceAfter, const Duration(seconds: 1));
      expect(plan.segments.first.repeat, 1, reason: 'each reading restarts');
    });

    test('an unlimited range repeat comes back to the range start', () {
      final segments = _plan(
        WholeSurah(8),
        repeat: const RepeatMode.unlimited(RepeatUnit.range),
        continueToNextSurah: true,
      ).segments.take(10000).toList();
      expect(segments.map((s) => s.address.surah).toSet(), {8});
      expect(_brief(segments.skip(9998)), ['ayah 8:1 #5000', 'ayah 8:2 #5000']);
    });
  });

  group('continue into the next surah (AU-04)', () {
    test('goes on surah by surah and stops after the last', () {
      final plan = _plan(WholeSurah(8), continueToNextSurah: true);
      expect(plan.continuesToNextSurah, isTrue);
      expect(plan.segments.map((s) => '${s.address.surah}:${s.address.ayah}'), [
        ..._span('8:1', '8:2'),
        ..._span('9:1', '9:9'),
        ..._span('10:1', '10:4'),
      ]);
      expect(
        _plan(WholeSurah(10), continueToNextSurah: true).segments,
        hasLength(4),
      );
    });

    test('repeats each surah before moving on', () {
      final segments = _plan(
        WholeSurah(9),
        repeat: RepeatMode(RepeatUnit.range, 2),
        continueToNextSurah: true,
        recitation: _recitation(basmala: true),
      ).segments;
      expect(
        segments
            .map((s) => '${s.kind.name} ${s.address.surah} #${s.repeat}')
            .toSet()
            .toList(),
        ['ayah 9 #1', 'ayah 9 #2', 'basmala 10 #1', 'ayah 10 #1', 'ayah 10 #2'],
      );
    });

    test('applies to a surah request only', () {
      final plan = _plan(SingleAyah(_a('8:2')), continueToNextSurah: true);
      expect(plan.continuesToNextSurah, isFalse);
      expect(plan.segments, hasLength(1));
    });
  });

  group('recitations served by surah files (D-112)', () {
    final bySurah = _recitation(unit: RecitationUnit.surah, basmala: true);

    test('whole surahs are planned as whole files', () {
      final plan = _plan(SurahSet(const [3, 7]), recitation: bySurah);
      expect(plan.hasAyahBoundaries, isFalse);
      expect(plan.segments.map((s) => s.source), [
        const SurahFile(3),
        const SurahFile(7),
      ]);
      expect(_brief(plan.segments), ['surah 3:1 #1', 'surah 7:1 #1']);
      expect(plan.segments.every((s) => s.endsSurah && !s.endsPage), isTrue);
      expect(
        _plan(WholeJuz(4), recitation: bySurah).segments.map((s) => s.source),
        [const SurahFile(9), const SurahFile(10)],
        reason: 'a juz made of whole surahs',
      );
      expect(
        _plan(ToEndOfMushaf(_a('9:1')), recitation: bySurah).segments,
        hasLength(2),
      );
    });

    test('a range with an ayah boundary is refused, never guessed', () {
      for (final range in [
        SingleAyah(_a('3:1')),
        AyahSpan(QuranRange(_a('3:1'), _a('3:4'))),
        PageSpan(4),
        WholeJuz(2),
        WholeHizb(4),
        ToEndOfMushaf(_a('9:2')),
        FromAyahTool(_a('3:1'), AyahToolEnd.page),
      ]) {
        expect(
          _refusal(range, recitation: bySurah),
          PlanRefusal.needsAyahTiming,
          reason: '$range',
        );
      }
    });

    test('ayah and page repeats are refused; surah and range are planned', () {
      for (final unit in [RepeatUnit.ayah, RepeatUnit.page]) {
        expect(
          _refusal(
            WholeSurah(3),
            recitation: bySurah,
            repeat: RepeatMode(unit, 2),
          ),
          PlanRefusal.needsAyahTiming,
        );
      }
      expect(
        _brief(
          _plan(
            SurahSet(const [3, 4]),
            recitation: bySurah,
            repeat: RepeatMode(RepeatUnit.surah, 2),
          ).segments,
        ),
        ['surah 3:1 #1', 'surah 3:1 #2', 'surah 4:1 #1', 'surah 4:1 #2'],
      );
      expect(
        _brief(
          _plan(
            SurahSet(const [3, 4]),
            recitation: bySurah,
            repeat: RepeatMode(RepeatUnit.range, 2),
          ).segments,
        ),
        ['surah 3:1 #1', 'surah 4:1 #1', 'surah 3:1 #2', 'surah 4:1 #2'],
      );
    });

    test('continue goes on with whole files', () {
      expect(
        _plan(
          WholeSurah(8),
          recitation: bySurah,
          continueToNextSurah: true,
        ).segments.map((s) => s.source),
        [const SurahFile(8), const SurahFile(9), const SurahFile(10)],
      );
    });

    test('with timing data, ayat are clips of the surah file', () {
      final plan = _plan(
        AyahSpan(QuranRange(_a('2:12'), _a('3:1'))),
        recitation: bySurah,
        timings: const _FakeTimings(),
      );
      expect(plan.hasAyahBoundaries, isTrue);
      expect(plan.segments.map((s) => s.source), [
        SurahClip(2, const Duration(seconds: 12), const Duration(seconds: 13)),
        SurahClip(3, Duration.zero, const Duration(seconds: 1)),
        SurahClip(3, const Duration(seconds: 1), const Duration(seconds: 2)),
      ]);
      expect(_brief(plan.segments), [
        'ayah 2:12 #1',
        'basmala 3:1 #1',
        'ayah 3:1 #1',
      ]);
    });

    test('with timing data that marks no basmala, none is heard', () {
      final plan = _plan(
        WholeSurah(3),
        recitation: bySurah,
        timings: const _FakeTimings(noBasmala: {3}),
      );
      expect(plan.segments.map((s) => s.kind).toSet(), {SegmentKind.ayah});
    });

    test('the isti\'adha file still opens a timed plan with no basmala', () {
      final plan = _plan(
        WholeSurah(3),
        recitation: _recitation(unit: RecitationUnit.surah, istiadha: true),
        timings: const _FakeTimings(noBasmala: {3}),
      );
      expect(_brief(plan.segments.take(2)), ['istiadha 3:1 #1', 'ayah 3:1 #1']);
      expect(plan.segments.first.source, const IstiadhaFile());
    });
  });
}
