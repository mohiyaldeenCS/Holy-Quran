import 'package:holyquran/data/repositories/player_repository.dart';
import 'package:holyquran/domain/models/playback_plan.dart';
import 'package:holyquran/domain/models/player_state.dart';
import 'package:holyquran/domain/models/sleep_timer.dart';
import 'package:holyquran/domain/models/stop_after.dart';

/// A [PlayerRepository] for view and widget tests: it plays nothing, shows
/// whatever [state] is set to and records every command in [commands].
final class FakePlayerRepository extends PlayerRepository {
  FakePlayerRepository({this._state = PlayerState.idle});

  PlayerState _state;
  final List<String> commands = [];

  @override
  PlayerState get state => _state;

  set state(PlayerState value) {
    _state = value;
    notifyListeners();
  }

  @override
  SleepTimer? sleepTimer;

  @override
  StopAfter? stopAfter;

  @override
  Duration? sleepRemaining;

  @override
  Future<void> play(PlaybackPlan plan, {int startAt = 0}) async {
    commands.add('play $startAt');
    state = _state.copyWith(
      plan: plan,
      playing: true,
      stopReason: () => null,
      error: () => null,
    );
  }

  @override
  Future<void> pause() async {
    commands.add('pause');
    state = _state.copyWith(playing: false);
  }

  @override
  Future<void> resume() async {
    commands.add('resume');
    state = _state.copyWith(playing: true, error: () => null);
  }

  @override
  Future<void> stop() async {
    commands.add('stop');
    state = _state.copyWith(playing: false);
  }

  @override
  Future<void> seek(Duration position) async {
    commands.add('seek ${position.inMilliseconds}');
    state = _state.copyWith(position: position);
  }

  @override
  Future<void> nextAyah() async => commands.add('nextAyah');

  @override
  Future<void> previousAyah() async => commands.add('previousAyah');

  @override
  Future<void> nextSurah() async => commands.add('nextSurah');

  @override
  Future<void> previousSurah() async => commands.add('previousSurah');

  @override
  Future<void> setSpeed(PlaybackSpeed speed) async {
    commands.add('speed ${speed.factor}');
    state = _state.copyWith(speed: speed);
  }

  @override
  Future<void> setSleepTimer(SleepTimer? timer) async {
    sleepTimer = timer;
    notifyListeners();
  }

  @override
  Future<void> setStopAfter(StopAfter? stopAfter) async {
    this.stopAfter = stopAfter;
    notifyListeners();
  }

  @override
  void enqueue(PlaybackPlan plan) =>
      state = _state.copyWith(queue: [..._state.queue, plan]);

  @override
  void moveInQueue(int from, int to) {
    final queue = [..._state.queue];
    RangeError.checkValidIndex(to, queue, 'to');
    queue.insert(to, queue.removeAt(from));
    state = _state.copyWith(queue: queue);
  }

  @override
  void removeFromQueue(int index) =>
      state = _state.copyWith(queue: [..._state.queue]..removeAt(index));
}
