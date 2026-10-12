import 'edition_map.dart';
import 'playback_plan.dart';
import 'playback_range.dart';
import 'playback_segment.dart';
import 'quran_address.dart';
import 'quran_range.dart';
import 'recitation.dart';
import 'repeat_mode.dart';

/// Ayah boundaries in one recitation's surah files, from its timing data
/// (registry row 6).
abstract interface class AyahTimings {
  SurahClip clipOf(QuranAddress ayah);

  /// The basmala before the first ayah of [surah], or null when the timing
  /// data marks none.
  SurahClip? basmalaOf(int surah);
}

/// Turns a play request into a [PlaybackPlan] over one reference edition.
/// Every boundary comes from the edition; none is estimated.
final class PlaybackPlanBuilder {
  /// [ayahCounts] holds each surah's ayah count, surah 1 first.
  /// [basmalaSurahs] are the surahs whose text has a separate basmala before
  /// its first ayah, as the pack's basmala field says.
  PlaybackPlanBuilder({
    required EditionMap edition,
    required List<int> ayahCounts,
    required Set<int> basmalaSurahs,
  }) : _edition = edition,
       _ayahCounts = List.unmodifiable(ayahCounts),
       _basmalaSurahs = Set.unmodifiable(basmalaSurahs) {
    for (final division in [Division.page, Division.juz, Division.hizb]) {
      if (edition.count(division) == 0) {
        throw ArgumentError('the edition has no ${division.name} starts');
      }
    }
    if (_ayahCounts.isEmpty || _ayahCounts.any((count) => count < 1)) {
      throw ArgumentError.value(ayahCounts, 'ayahCounts');
    }
  }

  static const maxSilence = Duration(seconds: 30);

  final EditionMap _edition;
  final List<int> _ayahCounts;
  final Set<int> _basmalaSurahs;

  String get _riwaya => _edition.startOf(Division.page, 1).riwaya;

  int get _surahCount => _ayahCounts.length;

  /// [continueToNextSurah] applies to a [WholeSurah] request only: the
  /// surahs after it follow, each with the same [repeat], up to the last
  /// surah (`AU-04`). [timings] gives ayah boundaries to a recitation served
  /// by surah files.
  PlanOutcome build(
    Recitation recitation,
    PlaybackRange range, {
    RepeatMode repeat = RepeatMode.once,
    Duration silence = Duration.zero,
    bool continueToNextSurah = false,
    AyahTimings? timings,
  }) {
    if (recitation.riwaya != _riwaya) {
      throw ArgumentError.value(
        recitation,
        'recitation',
        'is not in riwaya $_riwaya',
      );
    }
    if (silence.isNegative || silence > maxSilence) {
      throw RangeError.value(silence.inMilliseconds, 'silence');
    }
    if (!recitation.rightsComplete) {
      return const PlanRefused(PlanRefusal.rightsIncomplete);
    }
    final spans = _spans(range);
    final continues = continueToNextSurah && range is WholeSurah;
    final bounded = recitation.unit == RecitationUnit.ayah || timings != null;
    if (!bounded &&
        (!spans.every(_coversWholeSurahs) ||
            (repeat.count != 1 &&
                (repeat.unit == RepeatUnit.ayah ||
                    repeat.unit == RepeatUnit.page)))) {
      return const PlanRefused(PlanRefusal.needsAyahTiming);
    }
    final parts = continues
        ? [
            for (var surah = range.surah; surah <= _surahCount; surah++)
              [_wholeSurah(surah)],
          ]
        : [spans];
    final source = _Sources(recitation, timings);
    Iterable<PlaybackSegment> raw() sync* {
      if (recitation.hasIstiadhaFile) {
        yield PlaybackSegment(
          kind: SegmentKind.istiadha,
          address: spans.first.start,
          source: const IstiadhaFile(),
          repeat: 1,
        );
      }
      for (final part in parts) {
        yield* bounded
            ? _repeatedAyat(part, repeat, source)
            : _repeatedSurahs(part, repeat);
      }
    }

    return PlanReady(
      PlaybackPlan(
        recitation: recitation,
        range: range,
        repeat: repeat,
        silence: silence,
        continuesToNextSurah: continues,
        hasAyahBoundaries: bounded,
        segments: _withSilence(raw(), silence),
      ),
    );
  }

  /// The ayat [range] covers, in mushaf order.
  Iterable<QuranAddress> ayatOf(PlaybackRange range) => _ayatOf(_spans(range));

  List<QuranRange> _spans(PlaybackRange range) => switch (range) {
    SingleAyah(:final ayah) => [_span(ayah, ayah)],
    AyahSpan(range: QuranRange(:final start, :final end)) => [
      _span(start, end),
    ],
    PageSpan(:final first, :final last) => [
      _span(
        _edition.startOf(Division.page, first),
        _endOf(Division.page, last),
      ),
    ],
    WholeSurah(:final surah) => [_wholeSurah(surah)],
    WholeJuz(:final juz) => [_division(Division.juz, juz)],
    WholeHizb(:final hizb) => [_division(Division.hizb, hizb)],
    SurahSet(:final surahs) => [for (final surah in surahs) _wholeSurah(surah)],
    ToEndOfMushaf(:final from) => [_span(from, _lastOfMushaf)],
    FromAyahTool(:final ayah, :final until) => [
      _span(ayah, switch (until) {
        AyahToolEnd.ayah => ayah,
        AyahToolEnd.page => _endOf(
          Division.page,
          _edition.numberAt(Division.page, ayah),
        ),
        AyahToolEnd.surah => _lastOf(ayah.surah),
        AyahToolEnd.juz => _endOf(
          Division.juz,
          _edition.numberAt(Division.juz, ayah),
        ),
        AyahToolEnd.untilStopped => _lastOfMushaf,
      }),
    ],
  };

  QuranRange _span(QuranAddress start, QuranAddress end) {
    _check(start);
    _check(end);
    return QuranRange(start, end);
  }

  QuranRange _wholeSurah(int surah) {
    RangeError.checkValueInInterval(surah, 1, _surahCount, 'surah');
    return QuranRange(QuranAddress(_riwaya, surah, 1), _lastOf(surah));
  }

  QuranRange _division(Division division, int number) =>
      _span(_edition.startOf(division, number), _endOf(division, number));

  void _check(QuranAddress address) {
    if (address.riwaya != _riwaya) {
      throw ArgumentError.value(address, 'address', 'is not in $_riwaya');
    }
    RangeError.checkValueInInterval(address.surah, 1, _surahCount, 'surah');
    RangeError.checkValueInInterval(
      address.ayah,
      1,
      _ayahCounts[address.surah - 1],
      'ayah',
    );
  }

  QuranAddress _lastOf(int surah) =>
      QuranAddress(_riwaya, surah, _ayahCounts[surah - 1]);

  QuranAddress get _lastOfMushaf => _lastOf(_surahCount);

  /// The last ayah of unit [number] of [division].
  QuranAddress _endOf(Division division, int number) {
    final count = _edition.count(division);
    RangeError.checkValueInInterval(number, 1, count, division.name);
    return number == count
        ? _lastOfMushaf
        : _before(_edition.startOf(division, number + 1));
  }

  QuranAddress _before(QuranAddress ayah) => ayah.ayah > 1
      ? QuranAddress(_riwaya, ayah.surah, ayah.ayah - 1)
      : _lastOf(ayah.surah - 1);

  QuranAddress? _after(QuranAddress ayah) {
    if (ayah.ayah < _ayahCounts[ayah.surah - 1]) {
      return QuranAddress(_riwaya, ayah.surah, ayah.ayah + 1);
    }
    return ayah.surah < _surahCount
        ? QuranAddress(_riwaya, ayah.surah + 1, 1)
        : null;
  }

  bool _coversWholeSurahs(QuranRange span) =>
      span.start.ayah == 1 && span.end.ayah == _ayahCounts[span.end.surah - 1];

  Iterable<QuranAddress> _ayatOf(List<QuranRange> spans) sync* {
    for (final span in spans) {
      QuranAddress? ayah = span.start;
      while (ayah != null && ayah.compareTo(span.end) <= 0) {
        yield ayah;
        ayah = _after(ayah);
      }
    }
  }

  bool _endsPage(QuranAddress ayah) {
    final next = _after(ayah);
    return next == null ||
        _edition.numberAt(Division.page, next) !=
            _edition.numberAt(Division.page, ayah);
  }

  PlaybackSegment _heard(QuranAddress ayah, int repeat, _Sources sources) =>
      PlaybackSegment(
        kind: SegmentKind.ayah,
        address: ayah,
        source: sources.ayah(ayah),
        repeat: repeat,
        endsPage: _endsPage(ayah),
        endsSurah: ayah.ayah == _ayahCounts[ayah.surah - 1],
      );

  Iterable<PlaybackSegment> _basmalaBefore(
    QuranAddress ayah,
    _Sources sources,
  ) sync* {
    if (ayah.ayah != 1 || !_basmalaSurahs.contains(ayah.surah)) return;
    if (sources.basmala(ayah.surah) case final source?) {
      yield PlaybackSegment(
        kind: SegmentKind.basmala,
        address: ayah,
        source: source,
        repeat: 1,
      );
    }
  }

  /// One hearing of [ayat], each first ayah of a surah after its basmala.
  Iterable<PlaybackSegment> _pass(
    Iterable<QuranAddress> ayat,
    int pass,
    _Sources sources,
  ) sync* {
    for (final ayah in ayat) {
      yield* _basmalaBefore(ayah, sources);
      yield _heard(ayah, pass, sources);
    }
  }

  Iterable<PlaybackSegment> _repeatedAyat(
    List<QuranRange> spans,
    RepeatMode repeat,
    _Sources sources,
  ) sync* {
    final ayat = _ayatOf(spans);
    switch (repeat.unit) {
      case RepeatUnit.range:
        for (final pass in _passes(repeat.count)) {
          yield* _pass(ayat, pass, sources);
        }
      case RepeatUnit.ayah:
        for (final ayah in ayat) {
          yield* _basmalaBefore(ayah, sources);
          for (final pass in _passes(repeat.count)) {
            yield _heard(ayah, pass, sources);
          }
        }
      case RepeatUnit.page || RepeatUnit.surah:
        final byPage = repeat.unit == RepeatUnit.page;
        for (final group in _groups(
          ayat,
          (ayah) =>
              byPage ? _edition.numberAt(Division.page, ayah) : ayah.surah,
        )) {
          for (final pass in _passes(repeat.count)) {
            yield* _pass(group, pass, sources);
          }
        }
    }
  }

  Iterable<PlaybackSegment> _repeatedSurahs(
    List<QuranRange> spans,
    RepeatMode repeat,
  ) sync* {
    final surahs = [
      for (final span in spans)
        for (var surah = span.start.surah; surah <= span.end.surah; surah++)
          surah,
    ];
    PlaybackSegment whole(int surah, int pass) => PlaybackSegment(
      kind: SegmentKind.surah,
      address: QuranAddress(_riwaya, surah, 1),
      source: SurahFile(surah),
      repeat: pass,
      endsSurah: true,
    );
    if (repeat.unit == RepeatUnit.surah) {
      for (final surah in surahs) {
        for (final pass in _passes(repeat.count)) {
          yield whole(surah, pass);
        }
      }
    } else {
      for (final pass in _passes(repeat.count)) {
        for (final surah in surahs) {
          yield whole(surah, pass);
        }
      }
    }
  }
}

/// 1 to [count], or without end when [count] is null.
Iterable<int> _passes(int? count) sync* {
  for (var pass = 1; count == null || pass <= count; pass++) {
    yield pass;
  }
}

/// Runs of consecutive [ayat] that share a key.
Iterable<List<QuranAddress>> _groups(
  Iterable<QuranAddress> ayat,
  Object Function(QuranAddress ayah) keyOf,
) sync* {
  var group = <QuranAddress>[];
  Object? key;
  for (final ayah in ayat) {
    final next = keyOf(ayah);
    if (group.isNotEmpty && next != key) {
      yield group;
      group = [];
    }
    key = next;
    group.add(ayah);
  }
  if (group.isNotEmpty) yield group;
}

/// Silence after every ayah but the plan's last segment (`AU-11`).
Iterable<PlaybackSegment> _withSilence(
  Iterable<PlaybackSegment> segments,
  Duration silence,
) sync* {
  PlaybackSegment? held;
  for (final segment in segments) {
    if (held != null) yield _silenced(held, silence);
    held = segment;
  }
  if (held != null) yield held;
}

PlaybackSegment _silenced(PlaybackSegment segment, Duration silence) =>
    segment.kind == SegmentKind.ayah && silence > Duration.zero
    ? segment.withSilenceAfter(silence)
    : segment;

/// The recitation's own files for each piece (`AU-24`).
final class _Sources {
  const _Sources(this._recitation, this._timings);

  final Recitation _recitation;
  final AyahTimings? _timings;

  PlaybackSource ayah(QuranAddress ayah) =>
      _timings?.clipOf(ayah) ?? AyahFile(ayah);

  PlaybackSource? basmala(int surah) => switch (_timings) {
    final timings? => timings.basmalaOf(surah),
    null => _recitation.hasBasmalaFile ? const BasmalaFile() : null,
  };
}
