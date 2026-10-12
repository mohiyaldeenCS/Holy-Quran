import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/playback_rules.dart';
import 'package:holyquran/domain/models/player_state.dart';

void main() {
  group('PlaybackSpeed', () {
    test('has the seven steps of AU-06, normal among them', () {
      expect(PlaybackSpeed.all.map((speed) => speed.factor), [
        0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, //
      ]);
      expect(PlaybackSpeed.all, contains(PlaybackSpeed.normal));
      expect(PlaybackSpeed.normal.factor, 1.0);
    });

    test('steps one at a time and stops at both ends', () {
      for (final (index, speed) in PlaybackSpeed.all.indexed) {
        final last = PlaybackSpeed.all.length - 1;
        expect(
          speed.faster,
          PlaybackSpeed.all[index == last ? last : index + 1],
        );
        expect(speed.slower, PlaybackSpeed.all[index == 0 ? 0 : index - 1]);
      }
      expect(PlaybackSpeed.all.first.isSlowest, isTrue);
      expect(PlaybackSpeed.all.last.isFastest, isTrue);
      expect(
        PlaybackSpeed.normal.isSlowest || PlaybackSpeed.normal.isFastest,
        isFalse,
      );
    });
  });

  group('PlayerState', () {
    test('starts idle at normal speed', () {
      expect(PlayerState.idle.playing, isFalse);
      expect(PlayerState.idle.speed, PlaybackSpeed.normal);
      expect(PlayerState.idle.queue, isEmpty);
      expect(PlayerState.idle.repeat, isNull);
    });

    test('copyWith keeps what it is not given and clears on request', () {
      const failed = PlayerState(
        error: PlayerError.connectionFailed,
        stopReason: StopReason.user,
        position: Duration(seconds: 7),
      );
      final kept = failed.copyWith(playing: true);
      expect(kept.error, PlayerError.connectionFailed);
      expect(kept.stopReason, StopReason.user);
      expect(kept.position, const Duration(seconds: 7));
      final cleared = failed.copyWith(
        error: () => null,
        stopReason: () => null,
      );
      expect(cleared.error, isNull);
      expect(cleared.stopReason, isNull);
      expect(cleared.position, const Duration(seconds: 7));
    });
  });
}
