import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../../domain/models/pack_text.dart';
import 'audio_handler.dart';

/// One piece of audio for the engine: a whole file, or the part of it
/// between [start] and [end] when the plan has boundaries from timing data.
final class EngineTrack {
  const EngineTrack({
    required this.id,
    required this.uri,
    required this.streamed,
    this.start,
    this.end,
  });

  /// Chosen by the caller; the engine reports it back in [TrackEnded].
  final int id;
  final Uri uri;

  /// Whether it is read from the network rather than from a verified
  /// download; a failure while streaming is a lost connection.
  final bool streamed;
  final Duration? start;
  final Duration? end;
}

/// What the system shows on the lock screen and in the notification.
final class MediaInfo {
  const MediaInfo({required this.surahName, required this.reciter});

  /// From the base pack, unchanged (D-114).
  final PackText? surahName;
  final String reciter;

  @override
  bool operator ==(Object other) =>
      other is MediaInfo &&
      other.surahName == surahName &&
      other.reciter == reciter;

  @override
  int get hashCode => Object.hash(surahName, reciter);
}

/// A command from outside the app: the lock screen, the notification, a
/// headset button, or the audio session when a call or an unplugged headset
/// pauses playback and the system later resumes it (`AU-15`, `AU-22`).
sealed class RemoteCommand {
  const RemoteCommand();
}

final class RemotePlay extends RemoteCommand {
  const RemotePlay();
}

final class RemotePause extends RemoteCommand {
  const RemotePause();
}

final class RemoteStop extends RemoteCommand {
  const RemoteStop();
}

final class RemoteNext extends RemoteCommand {
  const RemoteNext();
}

final class RemotePrevious extends RemoteCommand {
  const RemotePrevious();
}

final class RemoteSeek extends RemoteCommand {
  const RemoteSeek(this.position);

  final Duration position;
}

enum EngineFailure { connection, playback }

sealed class EngineEvent {
  const EngineEvent();
}

/// The track [id] played to its end. When a next track was set, the engine
/// is playing it, with no gap, or starts it as soon as it is queued.
final class TrackEnded extends EngineEvent {
  const TrackEnded(this.id);

  final int id;
}

final class PositionChanged extends EngineEvent {
  const PositionChanged(this.position);

  /// Within the current track, from its start.
  final Duration position;
}

final class BufferingChanged extends EngineEvent {
  const BufferingChanged(this.buffering);

  final bool buffering;
}

/// The engine stopped on a failure of the current track.
final class EngineFailed extends EngineEvent {
  const EngineFailed(this.failure);

  final EngineFailure failure;
}

final class RemoteCommandReceived extends EngineEvent {
  const RemoteCommandReceived(this.command);

  final RemoteCommand command;
}

/// The only way to the audio plugins (D-111). It plays what it is told and
/// reports what happens; every decision is the player repository's.
abstract interface class AudioEngineService {
  Stream<EngineEvent> get events;

  /// Readies the media session; on Android 13 and later it asks for the
  /// notification permission the first time (D-126). Called before the
  /// first playback.
  Future<void> activate();

  /// Plays [track] from [from], within the track, and preloads [next].
  Future<void> play(EngineTrack track, {EngineTrack? next, Duration from});

  /// Loads [track] and holds at its start, as during a silence, so that
  /// [resume] starts it without waiting for the network (`AU-12`).
  Future<void> load(EngineTrack track);

  /// Sets the track that follows the current one without a gap, or none:
  /// the engine then holds at the end of the current track (`AU-12`).
  Future<void> setNext(EngineTrack? next);

  Future<void> pause();

  Future<void> resume();

  /// Shows the session as playing or paused without touching the player,
  /// as when a silence between ayat is paused or resumed.
  Future<void> setSessionPlaying(bool playing);

  Future<void> stop();

  /// From 0 to 1; the sleep timer's fade steps it down (`AU-07`).
  Future<void> setVolume(double volume);

  /// Within the current track.
  Future<void> seek(Duration position);

  /// Keeps the pitch (`AU-06`).
  Future<void> setSpeed(double factor);

  Future<void> setMediaInfo(MediaInfo info);

  Future<void> dispose();
}

/// Makes the handler that owns the player, with [onCommand] as its way out.
typedef AudioHandlerFactory = Future<AppAudioHandler> Function(
  void Function(RemoteCommand command) onCommand,
);

Future<AppAudioHandler> _initAudioService(
  void Function(RemoteCommand command) onCommand,
) => AudioService.init(
  builder: () => AppAudioHandler(onCommand),
  config: const AudioServiceConfig(
    androidNotificationChannelId: 'com.example.holyquran.playback',
  ),
);

/// [AudioEngineService] over `just_audio` behind `audio_service`. The
/// player holds the current track and at most the next one, so the next is
/// preloaded and follows without a gap. Nothing touches a plugin before
/// [activate].
final class PluginAudioEngineService implements AudioEngineService {
  /// [createHandler] is for tests, which run the engine over a fake player;
  /// the app uses the media session.
  PluginAudioEngineService({this._createHandler = _initAudioService});

  static const _permissionChannel = MethodChannel(
    'holyquran/notification_permission',
  );

  final AudioHandlerFactory _createHandler;
  final _events = StreamController<EngineEvent>.broadcast();
  final List<StreamSubscription<Object?>> _subscriptions = [];
  AppAudioHandler? _handler;
  Future<void>? _activating;
  double _speed = 1;

  /// The tracks the player holds, current first, as the playlist changes
  /// that have reached it leave them. A track queued by [setNext] is here
  /// only once the player has it, because an end is the end of a track the
  /// player had.
  List<EngineTrack> _tracks = [];
  Future<void> _playlistChanges = Future.value();
  int _playlist = 0;

  /// The playlist whose load has finished. Until it is [_playlist], what the
  /// player reports belongs to the playlist being replaced.
  int _loaded = 0;

  /// The track last given to [setNext], whether or not the player has it yet.
  EngineTrack? _wantedNext;

  /// The current track, when it ended and was reported before its successor
  /// was in the player. It stays first in [_tracks] until the successor is
  /// started, and is then removed from the player.
  EngineTrack? _endedHead;

  /// The track wanted after the head when the head's end was reported, which
  /// is the one the repository took to follow it. It alone is started, even
  /// if a later [setNext] wants another; that one queues behind it.
  EngineTrack? _successor;

  /// Whether the player advanced into [_successor] itself before the reply
  /// to its queueing reached us, so that it is playing already, and whether
  /// it then ended too.
  bool _successorStarted = false;
  bool _successorEnded = false;

  /// While the caller's seek is in flight a completion may be of the track
  /// as it was before the seek restarted it, and what the player reports
  /// about the playlist may lag behind it; the state is read again at the
  /// reply.
  bool _seeking = false;

  /// What the player was given for each track, to find it again by identity:
  /// indices shift while changes are in flight.
  final _sourceOf = Expando<AudioSource>();

  bool get _headEnded => _endedHead != null;

  AudioPlayer get _player =>
      (_handler ?? (throw StateError('the engine is not active'))).player;

  @override
  Stream<EngineEvent> get events => _events.stream;

  @override
  Future<void> activate() async {
    final activating = _activating ??= _activate();
    try {
      await activating;
    } on Exception {
      _activating = null;
      rethrow;
    }
  }

  Future<void> _activate() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _permissionChannel.invokeMethod<bool>('request');
      } on PlatformException {
        // Without the permission the media session still plays (S3).
      } on MissingPluginException {
        // The same holds without the channel.
      }
    }
    final handler = await _createHandler(
      (command) => _events.add(RemoteCommandReceived(command)),
    );
    _handler = handler;
    final player = handler.player;
    await player.setSpeed(_speed);
    _subscriptions
      ..add(player.positionDiscontinuityStream.listen(_onDiscontinuity))
      ..add(player.processingStateStream.listen(_onProcessingState))
      ..add(
        player.createPositionStream().listen(
          (position) => _events.add(PositionChanged(position)),
        ),
      )
      ..add(
        player.errorStream.listen((_) {
          if (!_loading) _failed();
        }),
      );
  }

  @override
  Future<void> play(
    EngineTrack track, {
    EngineTrack? next,
    Duration from = Duration.zero,
  }) async {
    _handler!.playing = true;
    _replacePlaylist(
      [track, ?next],
      from: from,
      then: () {
        if (_handler!.playing) _play();
      },
    );
  }

  @override
  Future<void> load(EngineTrack track) async {
    await _player.pause();
    _replacePlaylist([track]);
  }

  @override
  Future<void> setNext(EngineTrack? next) async {
    if (_tracks.isEmpty) return;
    _wantedNext = next;
    if (_headEnded && _successor == null) _successor = next;
    final generation = _playlist;
    _inOrder(() async {
      if (_tracks.length > 1) {
        final queued = _tracks[1];
        await _drop(queued);
        if (generation != _playlist) return;
        _tracks = [
          for (final track in _tracks)
            if (!identical(track, queued)) track,
        ];
      }
      if (next == null) return;
      await _player.addAudioSource(_source(next));
      if (generation != _playlist) return;
      _tracks = [..._tracks, next];
      if (_headEnded && identical(next, _successor)) {
        await _startQueued(generation, next);
      }
    });
  }

  @override
  Future<void> pause() async {
    _handler!.playing = false;
    await _player.pause();
  }

  @override
  Future<void> resume() async {
    _handler!.playing = true;
    _inOrder(() async {
      if (_handler!.playing) _play();
    });
  }

  @override
  Future<void> setSessionPlaying(bool playing) async =>
      _handler!.playing = playing;

  @override
  Future<void> stop() async {
    _invalidate();
    await _handler?.halt();
  }

  /// Forgets the playlist, so that nothing queued for it runs and nothing the
  /// player reports about it counts.
  void _invalidate() {
    _tracks = [];
    _wantedNext = null;
    _forgetEndedHead();
    _loaded = ++_playlist;
  }

  void _forgetEndedHead() {
    _endedHead = null;
    _successor = null;
    _successorStarted = false;
    _successorEnded = false;
  }

  bool get _loading => _loaded != _playlist;

  /// Whether the player is yet to receive the track after the current one.
  bool get _successorPending =>
      _wantedNext != null && !_tracks.any((t) => identical(t, _wantedNext));

  /// Whether the player already holds, right after the current track, the
  /// track that is wanted there.
  bool get _successorHeld =>
      _tracks.length > 1 && identical(_tracks[1], _wantedNext);

  /// Records that the current track ended before its successor could be
  /// started, and which track that is.
  void _headEndedBefore(EngineTrack? successor) {
    _endedHead = _tracks.first;
    _successor = successor;
    _events.add(TrackEnded(_tracks.first.id));
  }

  /// Starts the track just queued after one that ended before it arrived,
  /// unless the player already advanced into it, and drops the ended one.
  /// Until the seek to it replies, what the player reports may still be
  /// about the track it played before, so the head counts as ended until
  /// then.
  Future<void> _startQueued(int generation, EngineTrack next) async {
    final ended = _endedHead!;
    _tracks = [next];
    if (_successorStarted) {
      final finished = _successorEnded;
      _forgetEndedHead();
      if (finished) _onCompleted();
    } else {
      await _player.seek(Duration.zero, index: _indexOf(next));
      if (generation != _playlist) return;
      _forgetEndedHead();
      if (_handler!.playing) _play();
      _catchUp();
    }
    if (generation == _playlist) await _drop(ended);
  }

  int _indexOf(EngineTrack track) {
    final source = _sourceOf[track];
    return source == null ? -1 : _player.audioSources.indexOf(source);
  }

  /// Removes [track] from the player if it still holds it: a removal already
  /// in flight may have taken it.
  Future<void> _drop(EngineTrack track) async {
    final index = _indexOf(track);
    if (index >= 0) await _player.removeAudioSourceAt(index);
  }

  /// Brings the head up to what the player did while just_audio reported
  /// it to no one: it reports no advance from a seek's call to its reply,
  /// and the engine heeds nothing while a load is pending. An advance shows
  /// in the current index, an end in the processing state.
  void _catchUp() {
    if (_loading || _headEnded || _tracks.isEmpty) return;
    final head = _indexOf(_tracks.first);
    final index = _player.currentIndex;
    final completed = _player.processingState == ProcessingState.completed;
    if (head >= 0 &&
        index == head + 1 &&
        index! < _player.audioSources.length) {
      _advanced(index);
      if (!completed || _tracks.isEmpty) return;
      if (!_headEnded) {
        // The track advanced into ended too, before the caller could say
        // what follows it: the next [setNext] names its successor.
        _headEndedBefore(null);
      } else if (_successorStarted) {
        _successorEnded = true;
      }
    } else if (completed) {
      _onCompleted();
    }
  }

  // A failure while playing reaches errorStream, so the future's own error
  // is not needed.
  void _play() => unawaited(_player.play().catchError((Object _) {}));

  /// Loads [tracks] in place of the playlist, then runs [then], without
  /// making the caller wait: a stalled stream must hold back no command. A
  /// later replacement interrupts the load, and the changes queued for the
  /// old playlist are dropped.
  void _replacePlaylist(
    List<EngineTrack> tracks, {
    Duration? from,
    void Function()? then,
  }) {
    _tracks = tracks;
    _wantedNext = tracks.length > 1 ? tracks[1] : null;
    _forgetEndedHead();
    final generation = ++_playlist;
    _playlistChanges = _setTracks(tracks, generation, from: from)
        .then((_) {
          if (generation != _playlist) return;
          _loaded = generation;
          _catchUp();
          if (generation == _playlist) then?.call();
        })
        .catchError((Object _) {
          if (generation == _playlist) _failed();
        });
  }

  /// Runs [change] after the pending changes of the same playlist.
  void _inOrder(Future<void> Function() change) {
    final generation = _playlist;
    _playlistChanges = _playlistChanges
        .then((_) async {
          if (generation == _playlist) await change();
        })
        .catchError((Object _) {
          if (generation == _playlist) _failed();
        });
  }

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  /// Pinned to the head, so that it lands on the track the caller is at
  /// even if the player moved on before the seek reached it; dropped if the
  /// head's end was reported first, since the caller has moved on.
  @override
  Future<void> seek(Duration position) async => _inOrder(() async {
    if (_headEnded) return;
    final head = _tracks.isEmpty ? -1 : _indexOf(_tracks.first);
    _seeking = true;
    try {
      await _player.seek(position, index: head < 0 ? null : head);
    } finally {
      _seeking = false;
    }
    _catchUp();
  });

  @override
  Future<void> setSpeed(double factor) async {
    _speed = factor;
    await _handler?.player.setSpeed(factor);
  }

  @override
  Future<void> setMediaInfo(MediaInfo info) async => _handler?.show(info);

  @override
  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _handler?.dispose();
    await _events.close();
  }

  Future<void> _setTracks(
    List<EngineTrack> tracks,
    int generation, {
    Duration? from,
  }) async {
    try {
      await _player.setAudioSources([
        for (final track in tracks) _source(track),
      ], initialPosition: from);
    } on PlayerInterruptedException {
      // Replaced by a later load.
    } on PlayerException {
      if (generation == _playlist) _failed();
    }
  }

  AudioSource _source(EngineTrack track) {
    final file = ProgressiveAudioSource(track.uri);
    final source = track.start == null && track.end == null
        ? file
        : ClippingAudioSource(child: file, start: track.start, end: track.end);
    return _sourceOf[track] = source;
  }

  // Replacing the playlist is reported as an advance too; only a move from
  // the current track to the next one is.
  void _onDiscontinuity(PositionDiscontinuity discontinuity) {
    if (discontinuity.reason == PositionDiscontinuityReason.autoAdvance &&
        discontinuity.previousEvent.currentIndex == 0 &&
        discontinuity.event.currentIndex == 1 &&
        _player.audioSources.length > 1) {
      _advanced(1);
    }
  }

  /// The player moved from the head into the track at [index] of its
  /// playlist.
  void _advanced(int index) {
    if (_loading || _headEnded || _tracks.isEmpty) return;
    // The track advanced into becomes the head only if it is the one wanted
    // now. Otherwise it is a track being removed or replaced, because
    // stop-after or the sleep timer was toggled: taking it as the head would
    // report its end as the end of a track the repository no longer plays,
    // and the successor it wants would never start.
    if (_successorHeld) {
      final [ended, ...rest] = _tracks;
      _tracks = rest;
      _events.add(TrackEnded(ended.id));
      _inOrder(() => _drop(ended));
    } else if (_successorPending) {
      final successor = _wantedNext!;
      _headEndedBefore(successor);
      _successorStarted = identical(
        _player.audioSources[index],
        _sourceOf[successor],
      );
    }
  }

  void _onProcessingState(ProcessingState state) {
    _events.add(
      BufferingChanged(
        state == ProcessingState.loading || state == ProcessingState.buffering,
      ),
    );
    if (state != ProcessingState.completed || _loading || _tracks.isEmpty) {
      return;
    }
    if (_seeking) return;
    if (_headEnded) {
      if (_successorStarted) _successorEnded = true;
      return;
    }
    _onCompleted();
  }

  void _onCompleted() {
    final ended = _tracks.first;
    if (_successorHeld) {
      // The end reached us after the successor's queueing did.
      final successor = _wantedNext!;
      final generation = _playlist;
      _headEndedBefore(successor);
      _inOrder(() => _startQueued(generation, successor));
    } else if (_successorPending) {
      _headEndedBefore(_wantedNext!);
    } else {
      _invalidate();
      _events.add(TrackEnded(ended.id));
    }
  }

  // A player failure does not say whether the network caused it (S3), so a
  // streamed track's failure counts as a lost connection.
  void _failed() {
    if (_tracks.isEmpty) return;
    final streamed = (_successor ?? _tracks.first).streamed;
    _invalidate();
    _events.add(
      EngineFailed(
        streamed ? EngineFailure.connection : EngineFailure.playback,
      ),
    );
  }
}
