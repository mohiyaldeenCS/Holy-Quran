import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/playback_plan.dart';
import 'package:holyquran/domain/models/playback_range.dart';
import 'package:holyquran/domain/models/player_state.dart';
import 'package:holyquran/domain/models/recitation.dart';
import 'package:holyquran/domain/models/repeat_mode.dart';
import 'package:holyquran/domain/models/stop_after.dart';

import '../../../testing/fakes/fake_player_repository.dart';

final _plan = PlaybackPlan(
  recitation: Recitation(
    id: 'synthetic',
    reciter: 'Reciter A',
    riwaya: 'x',
    style: 'Style A',
    unit: RecitationUnit.ayah,
    hasWordTiming: false,
    rightsComplete: true,
  ),
  range: WholeSurah(1),
  repeat: RepeatMode.once,
  silence: Duration.zero,
  continuesToNextSurah: false,
  hasAyahBoundaries: true,
  segments: const [],
);

void main() {
  test('records commands and shows the state it is given', () async {
    final fake = FakePlayerRepository();
    var notified = 0;
    fake.addListener(() => notified++);
    await fake.resume();
    await fake.seek(const Duration(seconds: 2));
    await fake.setSpeed(PlaybackSpeed.normal.slower);
    await fake.nextAyah();
    await fake.pause();
    expect(fake.commands, [
      'resume',
      'seek 2000',
      'speed 0.75',
      'nextAyah',
      'pause',
    ]);
    expect(fake.state.playing, isFalse);
    expect(fake.state.position, const Duration(seconds: 2));
    expect(fake.state.speed, PlaybackSpeed.normal.slower);
    fake.state = const PlayerState(error: PlayerError.connectionFailed);
    expect(fake.state.error, PlayerError.connectionFailed);
    await expectLater(fake.setStopAfter(StopAfter.page), throwsStateError);
    fake.state = PlayerState(plan: _plan);
    await fake.setStopAfter(StopAfter.page);
    expect(fake.stopAfter, StopAfter.page);
    expect(notified, 7);
  });
}
