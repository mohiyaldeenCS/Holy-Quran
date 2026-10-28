import 'package:holyquran/domain/models/playback_plan.dart';
import 'package:holyquran/domain/models/playback_plan_builder.dart';
import 'package:holyquran/domain/models/playback_range.dart';
import 'package:holyquran/domain/models/playback_segment.dart';
import 'package:holyquran/domain/models/player_state.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/repeat_mode.dart';

/// [plan]'s request built again with what changes; what is not given keeps
/// its value. A new [range] keeps the run into the next surah when it is a
/// whole surah (`AU-04`); the builder ends every other range where it ends.
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
  continueToNextSurah: plan.continuesToNextSurah,
);

/// Where playback is in [state]: the ayah of the segment heard, or for a
/// whole surah its first ayah. [PlayerState.ayah] is not used, since only
/// ayah segments set it and a later plan does not clear it.
QuranAddress? heardIn(PlayerState state) => state.segment?.address;

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
/// not start the plan twice. A play the player refuses with an exception
/// reports false too, and the sheet stays as it is.
mixin PlaysOnce {
  bool _playing = false;

  Future<bool> playOnce(Future<bool> Function() play) async {
    if (_playing) return false;
    _playing = true;
    try {
      return await play();
    } on Exception {
      return false;
    } finally {
      _playing = false;
    }
  }
}
