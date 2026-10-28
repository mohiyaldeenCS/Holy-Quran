import 'package:holyquran/domain/models/playback_plan.dart';
import 'package:holyquran/domain/models/playback_plan_builder.dart';
import 'package:holyquran/domain/models/playback_range.dart';
import 'package:holyquran/domain/models/playback_segment.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/repeat_mode.dart';

/// [plan]'s request built again with what changes; what is not given keeps
/// its value. A new [range] does not continue into the next surah.
PlanOutcome rebuildPlan(
  PlaybackPlanBuilder builder,
  PlaybackPlan plan, {
  PlaybackRange? range,
  RepeatMode? repeat,
  Duration? silence,
}) => builder.build(
  plan.recitation,
  range ?? plan.range,
  repeat: repeat ?? plan.repeat,
  silence: silence ?? plan.silence,
  continueToNextSurah: range == null && plan.continuesToNextSurah,
);

/// The first segment of [plan] that plays [ayah], so that a rebuilt plan
/// goes on where the old one was; 0 when [ayah] is null or not in it, and
/// for a plan without end, whose segments a search might never finish.
int segmentOf(PlaybackPlan plan, QuranAddress? ayah) {
  if (ayah == null || plan.repeat.isUnlimited) return 0;
  var index = 0;
  for (final segment in plan.segments) {
    final at = segment.address;
    if (at.surah == ayah.surah &&
        (segment.kind == SegmentKind.surah || at.ayah == ayah.ayah)) {
      return index;
    }
    index++;
  }
  return 0;
}

/// A sheet's play, run once at a time: a tap while an earlier one is still
/// starting plays nothing and reports false, so that a fast double tap does
/// not start the plan twice.
mixin PlaysOnce {
  bool _playing = false;

  Future<bool> playOnce(Future<bool> Function() play) async {
    if (_playing) return false;
    _playing = true;
    try {
      return await play();
    } finally {
      _playing = false;
    }
  }
}
