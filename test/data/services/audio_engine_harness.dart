part of 'audio_engine_service_test.dart';

/// One playlist change on its way to the platform: the Dart-side list has
/// changed when it is issued, the platform when it [arrives], and the
/// caller hears of it when it is replied to.
final class _Change {
  _Change(this.kind, this.epoch, this.apply);

  final String kind;

  /// The load the change was issued after; a later load leaves it nothing
  /// to change.
  final int epoch;
  final void Function() apply;
  final reply = Completer<void>();
  bool arrived = false;

  /// How many reports the platform had sent when the change arrived; its
  /// reply follows them.
  int reportsBefore = 0;
}

/// What the platform reported and Dart has not yet seen.
sealed class _Outbound {}

final class _Advanced extends _Outbound {
  _Advanced(this.from, this.to);

  final int from;
  final int to;
}

/// A new current index with no advance: a seek to an index, or a removal
/// before the current track.
final class _Indexed extends _Outbound {
  _Indexed(this.index);

  final int index;
}

final class _Completed extends _Outbound {}

/// The player left the completed state, as a seek makes it.
final class _Ready extends _Outbound {}

/// A player whose events the test sends and whose playlist changes finish
/// only when the test says so, as on a device where a change takes a moment
/// to reach the platform. It follows just_audio 0.10.6:
///
/// - the Dart-side playlist changes when a change takes the playlist lock
///   (`removeAt`, just_audio.dart 3088-3090), the platform's when the
///   change arrives; a load waits for the adds and removals in flight
///   (`_init` takes the same lock, 3163-3165);
/// - an advance reaches [positionDiscontinuityStream] only if the Dart-side
///   playlist holds the track advanced to (287-300), and never from a seek's
///   call to its reply (`_seeking`, 298, 1316-1334), though [currentIndex]
///   still follows every report;
/// - [processingStateStream] repeats no state (`.distinct()`, 281-282);
/// - the platform's reports reach Dart in the order it sent them, and a
///   seek, an add or a removal replies after what the platform reported
///   before replying (AudioPlayer.java 493-517, 1031-1047: the playlist's
///   own adds and removals reply right after ExoPlayer's callbacks);
/// - an add or a removal that reaches a player that has ended moves it on:
///   set to play, into the track after the current one, if there is one;
///   paused, back to the start of the current track (`onTimelineChanged`,
///   AudioPlayer.java 304-323).
final class _FakePlayer extends Fake implements AudioPlayer {
  final _states = StreamController<ProcessingState>.broadcast(sync: true);
  final _jumps = StreamController<PositionDiscontinuity>.broadcast(sync: true);
  final _errors = StreamController<PlayerException>.broadcast(sync: true);
  final _playbackEvents = StreamController<PlaybackEvent>.broadcast();
  final _held = <String>{};
  final _pending = <String, List<_Change>>{};

  /// Every command, in the order the player received it.
  final List<String> calls = [];

  /// Every track the platform started, in order; null where a load or a
  /// seek to a position within a track starts a new hearing, after which a
  /// track may play again.
  final List<AudioSource?> starts = [];

  /// The track each seek to a position within a track landed on, in order.
  final List<String?> landings = [];

  /// The Dart-side playlist, as just_audio's `sequence` holds it.
  final List<AudioSource> _sources = [];

  final List<AudioSource> _platform = [];
  final List<_Outbound> _outbox = [];
  int _current = 0;
  int _reported = 0;
  int _sent = 0;
  int _seen = 0;
  bool _completed = false;

  /// The platform went back to the start of its current track while
  /// paused; playing it hears it again.
  bool _rewound = false;
  bool _playing = false;
  bool _seeking = false;
  ProcessingState _state = ProcessingState.ready;
  int _epoch = 0;
  int _loads = 0;

  @override
  Stream<ProcessingState> get processingStateStream => _states.stream;

  @override
  Stream<PositionDiscontinuity> get positionDiscontinuityStream =>
      _jumps.stream;

  @override
  Stream<PlayerException> get errorStream => _errors.stream;

  @override
  Stream<PlaybackEvent> get playbackEventStream => _playbackEvents.stream;

  @override
  Stream<Duration?> get durationStream => const Stream.empty();

  @override
  Stream<Duration> createPositionStream({
    int steps = 800,
    Duration minPeriod = const Duration(milliseconds: 200),
    Duration maxPeriod = const Duration(milliseconds: 200),
  }) => const Stream.empty();

  @override
  ProcessingState get processingState => _state;

  @override
  Duration get position => Duration.zero;

  @override
  Duration get bufferedPosition => Duration.zero;

  @override
  Duration? get duration => null;

  @override
  double get speed => 1;

  @override
  List<AudioSource> get audioSources => List.unmodifiable(_sources);

  /// The index the platform last reported that Dart has seen.
  @override
  int? get currentIndex => _sources.isEmpty ? null : _reported;

  /// Makes the next [kind] commands ('load', 'add', 'remove' or 'seek') wait for
  /// [release], or for [arrive] and then [reply].
  void hold(String kind) => _held.add(kind);

  void unhold(String kind) => _held.remove(kind);

  /// The names of the tracks in the Dart-side playlist, in order.
  List<String> get names => [for (final source in _sources) _name(source)];

  /// The names of the tracks the platform holds, in order.
  List<String> get platformNames => [
    for (final source in _platform) _name(source),
  ];

  /// The track the platform is playing, if it is playing one.
  String? get audible =>
      _playing && hasHead ? _name(_platform[_current]) : null;

  /// Whether the platform has a track that has not ended.
  bool get hasHead => !_completed && _current < _platform.length;

  bool get hasUnseen => _outbox.isNotEmpty;

  /// Whether a change is on its way or a report is unheard.
  bool get busy =>
      hasUnseen || _pending.values.any((changes) => changes.isNotEmpty);

  int arrivals(String kind) =>
      (_pending[kind] ?? []).where((c) => !c.arrived).length;

  int replies(String kind) =>
      (_pending[kind] ?? []).where((c) => c.arrived).length;

  /// The change reaches the platform, which the caller does not yet hear.
  void arrive(String kind) {
    final change = (_pending[kind] ?? []).firstWhere((c) => !c.arrived);
    change.arrived = true;
    if (change.epoch == _epoch) change.apply();
    change.reportsBefore = _sent;
  }

  /// The caller hears that the oldest change of [kind] is done.
  void reply(String kind, {Object? error}) {
    final change = _pending[kind]!.removeAt(0);
    assert(change.arrived, 'a reply before the change arrived');
    _seeUpTo(change.reportsBefore);
    if (error == null) {
      change.reply.complete();
    } else {
      change.reply.completeError(error);
    }
  }

  /// The oldest change of [kind] arrives, if it has not, and is replied to.
  void release(String kind, {Object? error}) {
    if (!_pending[kind]!.first.arrived) arrive(kind);
    reply(kind, error: error);
  }

  /// The platform reports [state]; a completion is the platform's own.
  void send(ProcessingState state) {
    if (state == ProcessingState.completed) _completed = true;
    _hear(state);
  }

  void _hear(ProcessingState state) => _states.add(_state = state);

  /// An advance from the first track to the second, as just_audio reports
  /// it: only if the Dart-side playlist has a second track.
  void advance() {
    if (_sources.length < 2) return;
    _jumps.add(
      PositionDiscontinuity(
        PositionDiscontinuityReason.autoAdvance,
        PlaybackEvent(currentIndex: 0),
        PlaybackEvent(currentIndex: 1),
      ),
    );
  }

  void replaced() => _jumps.add(
    PositionDiscontinuity(
      PositionDiscontinuityReason.autoAdvance,
      PlaybackEvent(currentIndex: 0),
      PlaybackEvent(currentIndex: 0),
    ),
  );

  void fail() => _errors.add(PlayerException(0, 'failed', null));

  /// The platform's current track ends: it goes on to the next one it
  /// holds, or completes. Dart hears of it at [deliver].
  void end() {
    assert(hasHead, 'nothing is playing to end');
    _rewound = false;
    if (_current + 1 < _platform.length) {
      _report(_Advanced(_current, ++_current));
      starts.add(_platform[_current]);
    } else {
      _complete();
    }
  }

  /// Dart hears of the oldest thing the platform reported.
  void deliver() {
    _seen++;
    switch (_outbox.removeAt(0)) {
      case _Advanced(:final from, :final to):
        _reported = to;
        if (!_seeking && _sources.length > to) {
          _jumps.add(
            PositionDiscontinuity(
              PositionDiscontinuityReason.autoAdvance,
              PlaybackEvent(currentIndex: from),
              PlaybackEvent(currentIndex: to),
            ),
          );
        }
      case _Indexed(:final index):
        _reported = index;
      case _Completed():
        _hear(ProcessingState.completed);
      case _Ready():
        _hear(ProcessingState.ready);
    }
  }

  /// Dart hears everything the platform reported.
  void seeAll() => _seeUpTo(_sent);

  void _seeUpTo(int reports) {
    while (_seen < reports) {
      deliver();
    }
  }

  void _report(_Outbound report) {
    _outbox.add(report);
    _sent++;
  }

  void _complete() {
    if (_completed) return;
    _completed = true;
    _report(_Completed());
  }

  /// What just_audio does when the playlist changes while the player has
  /// ended.
  void _moveOnIfEnded() {
    if (!_completed || _platform.isEmpty) return;
    if (_playing) {
      if (_current + 1 >= _platform.length) return;
      _report(_Advanced(_current, ++_current));
      starts.add(_platform[_current]);
    } else {
      _rewound = true;
    }
    _completed = false;
    _report(_Ready());
  }

  Future<void> _change(String kind, String call, void Function() apply) {
    calls.add(call);
    final change = _Change(kind, _epoch, apply);
    if (!_held.contains(kind)) {
      change.arrived = true;
      apply();
      _seeUpTo(_sent);
      return Future.value();
    }
    (_pending[kind] ??= []).add(change);
    return change.reply.future;
  }

  String _name(AudioSource source) => switch (source) {
    ProgressiveAudioSource(:final uri) => uri.pathSegments.last,
    ClippingAudioSource(:final child) => _name(child),
    _ => 'unknown',
  };

  @override
  Future<Duration?> setAudioSources(
    List<AudioSource> audioSources, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
    ShuffleOrder? shuffleOrder,
  }) async {
    final load = ++_loads;
    final locked = [
      for (final kind in ['add', 'remove'])
        for (final change in _pending[kind] ?? <_Change>[])
          change.reply.future.catchError((Object _) {}),
    ];
    if (locked.isNotEmpty) await Future.wait(locked);
    if (load != _loads) throw PlayerInterruptedException('replaced');
    _sources
      ..clear()
      ..addAll(audioSources);
    _epoch++;
    await _change('load', 'load ${audioSources.map(_name).join(',')}', () {
      // Platform messages reach Dart in the order they were sent, so what
      // was reported before the load arrived is heard before the load's
      // reply, while the engine is still loading and ignores it.
      _seen += _outbox.length;
      _outbox.clear();
      _platform
        ..clear()
        ..addAll(audioSources);
      _current = _reported = initialIndex ?? 0;
      _completed = false;
      _rewound = false;
      _state = ProcessingState.ready;
      starts.addAll([null, if (hasHead) _platform[_current]]);
    });
    return null;
  }

  @override
  Future<void> addAudioSource(AudioSource audioSource) {
    _sources.add(audioSource);
    return _change('add', 'add ${_name(audioSource)}', () {
      _platform.add(audioSource);
      _moveOnIfEnded();
    });
  }

  @override
  Future<void> removeAudioSourceAt(int index) {
    final removed = _sources.removeAt(index);
    return _change('remove', 'remove $index', () {
      final at = _platform.indexOf(removed);
      if (at < 0) return;
      _platform.removeAt(at);
      if (at < _current) {
        _report(_Indexed(--_current));
      } else if (at == _current) {
        _rewound = false;
        if (_current >= _platform.length) {
          // With no track after it, the player ends at the last one left.
          if (_platform.isNotEmpty) _report(_Indexed(--_current));
          _complete();
        } else if (!_completed) {
          starts.add(_platform[_current]);
        }
      }
      _moveOnIfEnded();
    });
  }

  @override
  Future<void> play() async {
    calls.add('play');
    _playing = true;
    if (_rewound && hasHead) starts.add(_platform[_current]);
    _rewound = false;
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    _playing = false;
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
    _playing = false;
  }

  @override
  Future<void> seek(Duration? position, {int? index}) async {
    _seeking = true;
    try {
      await _change('seek', 'seek ${index ?? '-'}', () {
        _rewound = false;
        if (index != null && index >= 0 && index < _platform.length) {
          _current = index;
          _report(_Indexed(index));
        }
        if (position != Duration.zero) {
          landings.add(
            _current < _platform.length ? _name(_platform[_current]) : null,
          );
        }
        if (_completed) _report(_Ready());
        _completed = false;
        if (_current < _platform.length) {
          starts.addAll([
            if (position != Duration.zero) null,
            _platform[_current],
          ]);
        }
      });
    } finally {
      _seeking = false;
    }
  }

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> dispose() async {
    await _states.close();
    await _jumps.close();
    await _errors.close();
    await _playbackEvents.close();
  }

  /// A track the platform started twice within one hearing, if any.
  String? get startedTwice {
    final heard = Set<AudioSource>.identity();
    for (final source in starts) {
      if (source == null) {
        heard.clear();
      } else if (!heard.add(source)) {
        return _name(source);
      }
    }
    return null;
  }
}

EngineTrack _track(int id, {bool streamed = true}) => EngineTrack(
  id: id,
  uri: Uri.parse('https://audio.test/$id'),
  streamed: streamed,
);

final class _Engine {
  final player = _FakePlayer();
  final events = <EngineEvent>[];
  late final PluginAudioEngineService engine;

  Future<void> start() async {
    engine = PluginAudioEngineService(
      createHandler: (onCommand) async =>
          AppAudioHandler(onCommand, player: player, watchSession: false),
    );
    engine.events.listen(events.add);
    await engine.activate();
  }

  /// The ids of the tracks the engine reported as ended.
  List<int> get ended => [
    for (final event in events)
      if (event case TrackEnded(:final id)) id,
  ];

  List<EngineFailure> get failures => [
    for (final event in events)
      if (event case EngineFailed(:final failure)) failure,
  ];

  /// Plays [track] and lets its load finish; the commands so far are
  /// forgotten.
  Future<void> playing(EngineTrack track, {EngineTrack? next}) async {
    await engine.play(track, next: next);
    await pumpEventQueue();
    player.calls.clear();
  }

  /// Each of these lets the engine's events reach [events].
  Future<void> send(ProcessingState state) async {
    player.send(state);
    await pumpEventQueue();
  }

  Future<void> advance() async {
    player.advance();
    await pumpEventQueue();
  }

  Future<void> replaced() async {
    player.replaced();
    await pumpEventQueue();
  }

  Future<void> fail() async {
    player.fail();
    await pumpEventQueue();
  }

  Future<void> dispose() => engine.dispose();
}

Future<_Engine> _started() async {
  final engine = _Engine();
  await engine.start();
  addTearDown(engine.dispose);
  return engine;
}

/// The engine's callers' view of the engine, to tell what the repository
/// asked for.
final class _SpyEngine implements AudioEngineService {
  _SpyEngine(this._inner);

  final PluginAudioEngineService _inner;

  /// The name of every track given to the engine, by id.
  final given = <int, String>{};

  /// The track the engine was last told to play after the current one.
  EngineTrack? wanted;

  /// Called as each seek is given to the engine.
  void Function()? onSeek;

  EngineTrack _note(EngineTrack track) {
    given[track.id] = track.uri.pathSegments.last;
    return track;
  }

  @override
  Stream<EngineEvent> get events => _inner.events;

  @override
  Future<void> activate() => _inner.activate();

  @override
  Future<void> play(
    EngineTrack track, {
    EngineTrack? next,
    Duration from = Duration.zero,
  }) {
    _note(track);
    wanted = next == null ? null : _note(next);
    return _inner.play(track, next: next, from: from);
  }

  @override
  Future<void> load(EngineTrack track) {
    wanted = null;
    return _inner.load(_note(track));
  }

  @override
  Future<void> setNext(EngineTrack? next) {
    wanted = next == null ? null : _note(next);
    return _inner.setNext(next);
  }

  @override
  Future<void> pause() => _inner.pause();

  @override
  Future<void> resume() => _inner.resume();

  @override
  Future<void> setSessionPlaying(bool playing) =>
      _inner.setSessionPlaying(playing);

  @override
  Future<void> stop() {
    wanted = null;
    return _inner.stop();
  }

  @override
  Future<void> setVolume(double volume) => _inner.setVolume(volume);

  @override
  Future<void> seek(Duration position) {
    onSeek?.call();
    return _inner.seek(position);
  }

  @override
  Future<void> setSpeed(double factor) => _inner.setSpeed(factor);

  @override
  Future<void> setMediaInfo(MediaInfo info) => _inner.setMediaInfo(info);

  @override
  Future<void> dispose() => _inner.dispose();
}

/// What a test of the race may do, each with the state in which it can
/// happen; an ordering that asks for one where it cannot is no ordering.
const _steps = {
  'end', // the platform's current track ends
  'see', // Dart hears of what the platform reported
  'arriveAdd',
  'replyAdd',
  'arriveRemove',
  'replyRemove',
  'arriveSeek',
  'replySeek',
  'arriveLoad',
  'replyLoad',
  'stopOn',
  'stopOff',
  'sleepOn',
  'sleepOff',
  'pause',
  'resume',
  'seek',
  'play',
};

/// Plays three ayat of a synthetic surah through the real repository over
/// the real engine and a fake player whose changes and reports the test
/// orders, and checks what the listener would hear.
final class _Race {
  _Race._(this.engine, this.spy, this.repository);

  final _Engine engine;
  final _SpyEngine spy;
  final EnginePlayerRepository repository;
  final indices = <int>[];
  final endedIds = <int>[];
  final problems = <String>[];
  var _replayed = false;

  /// For each seek given to the engine, the segment the repository was at
  /// and how many ends had been reported.
  final _seeks = <({String? segment, int ended})>[];
  var _landed = 0;

  _FakePlayer get player => engine.player;

  PlayerState get state => repository.state;

  static QuranAddress _a(String source) => QuranAddress.parse('x:$source');

  static final _builder = PlaybackPlanBuilder(
    edition: EditionMap(
      edition: 'synthetic',
      starts: {
        Division.page: [_a('1:1'), _a('2:1')],
        Division.juz: [_a('1:1')],
        Division.hizb: [_a('1:1')],
      },
      sajdas: const {},
    ),
    ayahCounts: const [3, 5],
    basmalaSurahs: const {2},
  );

  static final PlaybackPlan plan = switch (_builder.build(
    Recitation(
      id: 'synthetic',
      reciter: 'Reciter A',
      riwaya: 'x',
      style: 'Style A',
      unit: RecitationUnit.ayah,
      hasWordTiming: false,
      rightsComplete: true,
      hasBasmalaFile: true,
    ),
    AyahSpan(QuranRange(_a('1:1'), _a('1:3'))),
  )) {
    PlanReady(:final plan) => plan,
    PlanRefused(:final reason) => throw StateError('refused: $reason'),
  };

  /// The first ayah playing with the second queued behind it, and every
  /// later add and removal held until the ordering lets it through.
  static Future<_Race> start({
    Set<String> holding = const {'add', 'remove'},
  }) async {
    final engine = _Engine();
    await engine.start();
    final spy = _SpyEngine(engine.engine);
    final repository = EnginePlayerRepository(
      engine: spy,
      locate: (recitation, source) async =>
          (uri: Uri.parse('https://audio.test/$source'), streamed: true),
      surahName: (surah) async => null,
    );
    final race = _Race._(engine, spy, repository);
    engine.engine.events.listen(race._onEngine);
    spy.onSeek = () => race._seeks.add((
      segment: race._segmentName,
      ended: race.endedIds.length,
    ));
    repository.addListener(race._onState);
    await repository.play(plan);
    await _flush();
    holding.forEach(engine.player.hold);
    return race;
  }

  /// Everything the engine and the repository do in answer to a step is
  /// microtasks, so it has all happened when none is waiting. Only the
  /// zone of [_interleave] counts them.
  static Future<void> _flush() async {
    do {
      await Future<void>.value();
    } while (_queued > 0);
  }

  static int _queued = 0;

  String? get _segmentName => state.segment?.source.toString();

  bool get _running => state.plan != null && state.stopReason == null;

  void _onState() {
    final index = state.segmentIndex;
    if (index != null && index != indices.lastOrNull) indices.add(index);
  }

  void _onEngine(EngineEvent event) {
    if (event is! TrackEnded) return;
    endedIds.add(event.id);
    final name = spy.given[event.id];
    if (name == null) {
      problems.add('TrackEnded(${event.id}) is no track the repository gave');
    } else if (name != _segmentName) {
      problems.add(
        'TrackEnded(${event.id}) is $name while the repository is at '
        '$_segmentName',
      );
    }
  }

  bool can(String step) => switch (step) {
    'end' => player.audible != null,
    'see' => player.hasUnseen,
    'arriveAdd' => player.arrivals('add') > 0,
    'replyAdd' => player.replies('add') > 0,
    'arriveRemove' => player.arrivals('remove') > 0,
    'replyRemove' => player.replies('remove') > 0,
    'arriveSeek' => player.arrivals('seek') > 0,
    'replySeek' => player.replies('seek') > 0,
    'arriveLoad' => player.arrivals('load') > 0,
    'replyLoad' => player.replies('load') > 0,
    'stopOn' => _running && repository.stopAfter == null,
    'stopOff' => _running && repository.stopAfter != null,
    'sleepOn' => _running && repository.sleepTimer == null,
    'sleepOff' => _running && repository.sleepTimer != null,
    'pause' => _running && state.playing,
    'resume' => _running && !state.playing,
    'seek' => _running && state.playing,
    'play' => true,
    _ => throw ArgumentError(step),
  };

  Future<void> run(String step) async {
    final endedBefore = endedIds.length;
    final indexBefore = state.segmentIndex;
    switch (step) {
      case 'end':
        player.end();
      case 'see':
        player.deliver();
      case 'arriveAdd':
        player.arrive('add');
      case 'replyAdd':
        player.reply('add');
      case 'arriveRemove':
        player.arrive('remove');
      case 'replyRemove':
        player.reply('remove');
      case 'arriveSeek':
        player.arrive('seek');
      case 'replySeek':
        player.reply('seek');
      case 'arriveLoad':
        player.arrive('load');
      case 'replyLoad':
        player.reply('load');
      case 'stopOn':
        unawaited(repository.setStopAfter(StopAfter.ayah));
      case 'stopOff':
        unawaited(repository.setStopAfter(null));
      case 'sleepOn':
        unawaited(repository.setSleepTimer(const SleepAtEndOfAyah()));
      case 'sleepOff':
        unawaited(repository.setSleepTimer(null));
      case 'pause':
        unawaited(repository.pause());
      case 'resume':
        unawaited(repository.resume());
      case 'seek':
        unawaited(repository.seek(const Duration(seconds: 1)));
      case 'play':
        _replayed = true;
        unawaited(repository.play(plan));
    }
    await _flush();
    _checkLandings();
    if (step != 'play' && endedIds.length > endedBefore) {
      final advanced = (state.segmentIndex ?? 0) - (indexBefore ?? 0);
      if (state.stopReason == null &&
          advanced != endedIds.length - endedBefore) {
        problems.add(
          'after $step the repository ignored the end of '
          '${endedIds.skip(endedBefore).join(',')}',
        );
      }
    }
    if (!player.busy) checkSettled('after $step');
  }

  /// A seek lands on the segment the repository was at when it gave it. The
  /// engine drops it only if that segment's end was reported first.
  void _checkLandings() {
    while (_landed < player.landings.length) {
      final landing = player.landings[_landed++];
      String? dropped;
      while (true) {
        if (_seeks.isEmpty) {
          problems.add(
            dropped == null
                ? 'a seek landed on $landing, but none was given'
                : 'a seek given at $dropped landed on $landing after the end '
                      'of $dropped was reported',
          );
          return;
        }
        final seek = _seeks.removeAt(0);
        if (landing == seek.segment) break;
        if (endedIds.length == seek.ended) {
          problems.add('a seek given at ${seek.segment} landed on $landing');
          return;
        }
        dropped = seek.segment;
      }
    }
  }

  /// Lets every change through and every report be heard.
  Future<void> drain() async {
    for (var round = 0; round < 40; round++) {
      var moved = false;
      if (player.hasUnseen) {
        player.deliver();
        moved = true;
      }
      for (final kind in ['remove', 'add', 'seek', 'load']) {
        if (player.arrivals(kind) > 0) {
          player.arrive(kind);
          moved = true;
        } else if (player.replies(kind) > 0) {
          player.reply(kind);
          moved = true;
        }
      }
      await _flush();
      _checkLandings();
      if (!moved) return;
    }
    problems.add('the player never settled');
  }

  /// What must hold once every change is through: the player plays the
  /// repository's segment, or nothing while it is paused or stopped, and a
  /// track it still wants is in the player.
  void checkSettled(String when) {
    if (!_running || !state.playing) {
      if (player.audible != null) {
        problems.add(
          '$when: ${_running ? 'paused at $_segmentName' : 'stopped'}, '
          'but ${player.audible} is playing',
        );
      }
      if (!_running) return;
    } else if (player.audible != _segmentName) {
      problems.add(
        '$when: the repository plays $_segmentName, the player '
        '${player.audible} (holds ${player.platformNames})',
      );
    }
    final wanted = spy.wanted;
    if (wanted != null &&
        !endedIds.contains(wanted.id) &&
        !player.platformNames.contains(spy.given[wanted.id])) {
      problems.add(
        '$when: wanted ${spy.given[wanted.id]} is not in the player '
        '${player.platformNames}',
      );
    }
  }

  /// Plays on to the end of the plan, checking after every ayah.
  Future<void> playOn() async {
    if (_running && !state.playing) {
      await repository.resume();
      await _flush();
      await drain();
    }
    for (var ayah = 0; ayah < 6 && _running && problems.isEmpty; ayah++) {
      checkSettled('while playing on');
      if (problems.isNotEmpty || player.audible == null) break;
      await run('end');
      await run('see');
      await drain();
    }
    checkSettled('at the end');
    if (_running) problems.add('the plan did not end');
  }

  /// No track is heard twice: each starts once, unless a new play or a
  /// seek within a track begins a new hearing.
  void checkStarts() {
    if (player.startedTwice case final name?) {
      problems.add('$name started twice');
    }
  }

  /// No ayah is skipped: each move goes to the next segment, or back to
  /// the start after a new play.
  void checkOrder() {
    for (var i = 1; i < indices.length; i++) {
      final jump = indices[i] - indices[i - 1];
      if (jump != 1 && !(_replayed && indices[i] == 0)) {
        problems.add('the segments ${indices.join(' > ')} skip or repeat one');
        return;
      }
    }
  }

  Future<void> dispose() async {
    repository.dispose();
    await engine.dispose();
  }
}

/// Runs every causal ordering of the [steps] a scenario allows, each at most
/// as often as its count says, and returns how many there were and what went
/// wrong in each that failed. An ordering ends when no step can be taken.
Future<({int orderings, List<String> failures})> _interleave(
  Map<String, int> steps, {
  Set<String> holding = const {'add', 'remove'},
}) {
  assert(steps.keys.every(_steps.contains));
  var orderings = 0;
  final failures = <String>[];
  // Where an ordering could have gone another way; each is run to its end
  // by a fresh race that repeats what came before.
  final branches = <List<String>>[[]];

  Future<void> explore(List<String> branch) async {
    final race = await _Race.start(holding: holding);
    final order = <String>[];
    try {
      for (final step in branch) {
        await race.run(step);
        order.add(step);
      }
      while (true) {
        final enabled = [
          for (final step in steps.keys)
            if (order.where((s) => s == step).length < steps[step]! &&
                race.can(step))
              step,
        ];
        if (enabled.isEmpty) break;
        for (final other in enabled.skip(1)) {
          branches.add([...order, other]);
        }
        await race.run(enabled.first);
        order.add(enabled.first);
      }
      orderings++;
      await race.drain();
      race.checkSettled('after ${order.join(' > ')}');
      await race.playOn();
      race
        ..checkOrder()
        ..checkStarts();
      if (race.problems.isNotEmpty) {
        failures.add('${order.join(' > ')}: ${race.problems.first}');
      }
    } finally {
      await race.dispose();
    }
  }

  return _counted(() async {
    while (branches.isNotEmpty) {
      await explore(branches.removeLast());
    }
    return (orderings: orderings, failures: failures);
  });
}

/// Runs [steps] in order as one ordering of the walk, skipping those the
/// state does not allow, then plays on, and returns what went wrong.
Future<List<String>> _replay(
  List<String> steps, {
  Set<String> holding = const {'add', 'remove'},
}) => _counted(() async {
  final race = await _Race.start(holding: holding);
  try {
    for (final step in steps) {
      if (race.can(step)) await race.run(step);
    }
    await race.drain();
    await race.playOn();
    race
      ..checkOrder()
      ..checkStarts();
    return race.problems;
  } finally {
    await race.dispose();
  }
});

/// Runs [body] in a zone that counts pending microtasks for [_Race._flush].
Future<T> _counted<T>(Future<T> Function() body) => runZoned(
  body,
  zoneSpecification: ZoneSpecification(
    scheduleMicrotask: (self, parent, zone, task) {
      _Race._queued++;
      parent.scheduleMicrotask(zone, () {
        _Race._queued--;
        task();
      });
    },
  ),
);
