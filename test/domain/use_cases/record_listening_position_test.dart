import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/listening_position.dart';
import 'package:holyquran/domain/models/playback_plan.dart';
import 'package:holyquran/domain/models/playback_range.dart';
import 'package:holyquran/domain/models/playback_rules.dart';
import 'package:holyquran/domain/models/player_state.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/quran_range.dart';
import 'package:holyquran/domain/models/recitation.dart';
import 'package:holyquran/domain/use_cases/record_listening_position.dart';

import '../../ui/features/listen/controls/controls_harness.dart';

QuranAddress _at(int surah, int ayah) => QuranAddress('hafs', surah, ayah);

void main() {
  final builder = syntheticBuilder(syntheticIndex());
  final PlaybackPlan plan = planOf(builder, SingleAyah(_at(1, 2)));
  final PlaybackPlan wholeSurah = planOf(
    builder,
    AyahSpan(QuranRange(_at(1, 1), _at(1, 3))),
  );

  PlayerState playing(Duration at, {PlaybackPlan? of, int segment = 0}) {
    final played = of ?? plan;
    return PlayerState(
      plan: played,
      segment: played.segments.elementAt(segment),
      segmentIndex: segment,
      position: at,
      playing: true,
    );
  }

  late List<ListeningPosition> saved;
  late RecordListeningPosition recorder;

  setUp(() {
    saved = [];
    recorder = RecordListeningPosition(save: (p) async => saved.add(p));
  });
  tearDown(() => recorder.dispose());

  ListeningPosition position(Duration at) => ListeningPosition(
    address: _at(1, 2),
    recitationId: syntheticRecitation().id,
    offset: at,
  );

  test('saves nothing while nothing has played', () {
    fakeAsync((async) {
      recorder.update(PlayerState.idle);
      async.elapse(const Duration(minutes: 1));
      expect(saved, isEmpty);
    });
  });

  test('saves every ten seconds while playing, with the latest offset', () {
    fakeAsync((async) {
      recorder.update(playing(Duration.zero));
      async.elapse(const Duration(seconds: 9));
      expect(saved, isEmpty);

      recorder.update(playing(const Duration(seconds: 9)));
      async.elapse(const Duration(seconds: 1));
      expect(saved, [position(const Duration(seconds: 9))]);

      recorder.update(playing(const Duration(seconds: 19)));
      async.elapse(const Duration(seconds: 10));
      expect(saved, hasLength(2));
      expect(saved.last, position(const Duration(seconds: 19)));
    });
  });

  test('saves on pause and then stops the clock', () {
    fakeAsync((async) {
      final state = playing(const Duration(seconds: 3));
      recorder.update(state);
      recorder.update(state.copyWith(playing: false));
      expect(saved, [position(const Duration(seconds: 3))]);

      async.elapse(const Duration(minutes: 1));
      expect(saved, hasLength(1));
    });
  });

  test('saves on a stop by the user, which keeps the segment in the state', () {
    final state = playing(const Duration(seconds: 4));
    recorder.update(state);
    recorder.update(
      state.copyWith(playing: false, stopReason: () => StopReason.user),
    );

    expect(saved, [position(const Duration(seconds: 4))]);
  });

  test('saves the ayah heard, not the first of the plan', () {
    final state = playing(const Duration(seconds: 2), of: wholeSurah, segment: 1);
    recorder.update(state);
    recorder.update(state.copyWith(playing: false));

    expect(saved.single.address, _at(1, 2));
    expect(saved.single.offset, const Duration(seconds: 2));
  });

  test('keeps no offset at the end of a plan', () {
    final state = playing(const Duration(seconds: 7));
    recorder.update(state);
    recorder.update(
      state.copyWith(playing: false, stopReason: () => StopReason.endOfPlan),
    );

    expect(saved, [position(Duration.zero)]);
  });

  test('keeps no offset in a silence, whose segment has been heard', () {
    final state = playing(
      const Duration(seconds: 7),
    ).copyWith(inSilence: true);
    recorder.update(state);
    recorder.update(state.copyWith(playing: false));

    expect(saved, [position(Duration.zero)]);
  });

  test('keeps no offset in the istiʿadha before the ayah', () {
    final withIstiadha = planOf(
      builder,
      SingleAyah(_at(1, 2)),
      recitation: Recitation(
        id: 'synthetic-istiadha',
        reciter: 'Synthetic reciter',
        riwaya: 'hafs',
        style: 'Synthetic style',
        unit: RecitationUnit.ayah,
        hasWordTiming: false,
        rightsComplete: true,
        hasIstiadhaFile: true,
      ),
    );
    final state = playing(const Duration(seconds: 1), of: withIstiadha);
    recorder.update(state);
    recorder.update(state.copyWith(playing: false));

    expect(
      saved.single,
      ListeningPosition(
        address: _at(1, 2),
        recitationId: 'synthetic-istiadha',
        offset: Duration.zero,
      ),
    );
  });

  test('records again after playing again', () {
    fakeAsync((async) {
      final state = playing(const Duration(seconds: 3));
      recorder.update(state);
      recorder.update(state.copyWith(playing: false));
      recorder.update(playing(const Duration(seconds: 3)));
      async.elapse(const Duration(seconds: 10));

      expect(saved, hasLength(2));
    });
  });
}
