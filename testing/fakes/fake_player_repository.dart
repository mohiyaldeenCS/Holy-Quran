import 'package:holyquran/data/repositories/player_repository.dart';
import 'package:holyquran/domain/models/playback_plan.dart';
import 'package:holyquran/domain/models/playback_rules.dart';
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

  /// Thrown by the next [play], as the real repository may throw.
  Exception? playFailure;

  @override
  Future<void> play(PlaybackPlan plan, {int startAt = 0}) async {
    if (playFailure case final failure?) {
      playFailure = null;
      throw failure;
    }
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
    state = _state.copyWith(playing: false, stopReason: () => StopReason.user);
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

  /// Fails as the real repository does when nothing is playing.
  @override
  Future<void> setSleepTimer(SleepTimer? timer) async {
    _checkPlaying();
    sleepTimer = timer;
    notifyListeners();
  }

  @override
  Future<void> setStopAfter(StopAfter? stopAfter) async {
    _checkPlaying();
    this.stopAfter = stopAfter;
    notifyListeners();
  }

  void _checkPlaying() {
    if (_state.plan == null || _state.stopReason != null) {
      throw StateError('nothing is playing');
    }
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
