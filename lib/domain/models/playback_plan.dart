import 'playback_range.dart';
import 'playback_segment.dart';
import 'recitation.dart';
import 'repeat_mode.dart';
import 'sleep_timer.dart';
import 'stop_after.dart';

/// A play request turned into ordered timed segments with their repeats and
/// silences (PRD §8.3).
final class PlaybackPlan {
  const PlaybackPlan({
    required this.recitation,
    required this.range,
    required this.repeat,
    required this.silence,
    required this.continuesToNextSurah,
    required this.hasAyahBoundaries,
    required this.segments,
  });

  final Recitation recitation;
  final PlaybackRange range;
  final RepeatMode repeat;
  final Duration silence;
  final bool continuesToNextSurah;

  /// False when the recitation is served by surah files without timing data:
  /// the plan then holds whole surahs only and knows no ayah or page end
  /// (D-112).
  final bool hasAyahBoundaries;

  /// Built lazily as it is read, so an unlimited repeat never ends; each
  /// reading starts again from the first segment.
  final Iterable<PlaybackSegment> segments;

  bool supportsStopAfter(StopAfter stopAfter) =>
      hasAyahBoundaries || stopAfter == StopAfter.surah;

  bool supportsSleepTimer(SleepTimer timer) =>
      hasAyahBoundaries || timer is! SleepAtEndOfAyah;
}

/// Why a request has no plan.
enum PlanRefusal {
  /// The recitation's rights record is not complete.
  rightsIncomplete,

  /// The request needs ayah boundaries that the recitation's surah files do
  /// not have without timing data (D-112).
  needsAyahTiming,
}

sealed class PlanOutcome {
  const PlanOutcome();
}

final class PlanReady extends PlanOutcome {
  const PlanReady(this.plan);

  final PlaybackPlan plan;
}

final class PlanRefused extends PlanOutcome {
  const PlanRefused(this.reason);

  final PlanRefusal reason;
}
