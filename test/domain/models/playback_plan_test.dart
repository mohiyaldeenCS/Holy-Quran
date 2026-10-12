import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/playback_plan.dart';
import 'package:holyquran/domain/models/playback_range.dart';
import 'package:holyquran/domain/models/recitation.dart';
import 'package:holyquran/domain/models/repeat_mode.dart';
import 'package:holyquran/domain/models/sleep_timer.dart';
import 'package:holyquran/domain/models/stop_after.dart';

PlaybackPlan _plan({required bool hasAyahBoundaries}) => PlaybackPlan(
  recitation: Recitation(
    id: 'a',
    reciter: 'Reciter A',
    riwaya: 'x',
    style: 'Style A',
    unit: RecitationUnit.surah,
    hasWordTiming: false,
    rightsComplete: true,
  ),
  range: WholeSurah(1),
  repeat: RepeatMode.once,
  silence: Duration.zero,
  continuesToNextSurah: false,
  hasAyahBoundaries: hasAyahBoundaries,
  segments: const [],
);

void main() {
  test('with ayah boundaries, every stop-after and sleep timer applies', () {
    final plan = _plan(hasAyahBoundaries: true);
    expect(StopAfter.values.every(plan.supportsStopAfter), isTrue);
    expect(plan.supportsSleepTimer(const SleepAtEndOfAyah()), isTrue);
  });

  test('without them, only surah ends and minutes apply (D-112)', () {
    final plan = _plan(hasAyahBoundaries: false);
    expect(StopAfter.values.where(plan.supportsStopAfter), [StopAfter.surah]);
    expect(plan.supportsSleepTimer(const SleepAtEndOfAyah()), isFalse);
    expect(plan.supportsSleepTimer(const SleepAtEndOfSurah()), isTrue);
    expect(plan.supportsSleepTimer(SleepAfter(10)), isTrue);
  });
}
