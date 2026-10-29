import 'package:holyquran/domain/models/playback_plan.dart';
import 'package:holyquran/domain/models/playback_range.dart';
import 'package:holyquran/domain/models/playback_segment.dart';
import 'package:holyquran/domain/models/player_state.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/recitation.dart';
import 'package:holyquran/domain/models/repeat_mode.dart';

import '../../../../testing/fakes/fake_player_repository.dart';

QuranAddress ayahAt(int surah, int ayah) => QuranAddress('hafs', surah, ayah);

final _recitation = Recitation(
  id: 'synthetic-recitation',
  reciter: 'Synthetic reciter',
  riwaya: 'hafs',
  style: 'Synthetic style',
  unit: RecitationUnit.ayah,
  hasWordTiming: false,
  rightsComplete: true,
);

/// A plan the player can hold; its segments are never read, the tests give
/// the player's state the segments to show. [boundaries] false is a
/// recitation served as whole surahs without timing data (D-112).
PlaybackPlan recitationPlan({bool boundaries = true}) => PlaybackPlan(
  recitation: _recitation,
  range: FromAyahTool(ayahAt(2, 1), AyahToolEnd.surah),
  repeat: RepeatMode.once,
  silence: Duration.zero,
  continuesToNextSurah: false,
  hasAyahBoundaries: boundaries,
  segments: const [],
);

PlaybackSegment ayahSegment(int surah, int ayah) => PlaybackSegment(
  kind: SegmentKind.ayah,
  address: ayahAt(surah, ayah),
  source: AyahFile(ayahAt(surah, ayah)),
  repeat: 1,
);

PlaybackSegment basmalaSegment(int surah) => PlaybackSegment(
  kind: SegmentKind.basmala,
  address: ayahAt(surah, 1),
  source: const BasmalaFile(),
  repeat: 1,
);

PlaybackSegment surahSegment(int surah) => PlaybackSegment(
  kind: SegmentKind.surah,
  address: ayahAt(surah, 1),
  source: SurahFile(surah),
  repeat: 1,
);

extension RecitationStates on FakePlayerRepository {
  /// The player reaches [segment] of [plan], as the real one announces an
  /// ayah's segment together with its ayah event.
  void reach(PlaybackPlan plan, PlaybackSegment segment, {int index = 0}) {
    state = PlayerState(
      plan: plan,
      segment: segment,
      segmentIndex: index,
      ayah: segment.kind == SegmentKind.ayah ? segment.address : state.ayah,
      playing: true,
      speed: state.speed,
    );
  }
}
