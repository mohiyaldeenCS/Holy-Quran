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
/// is already playing it, with no gap.
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

/// [AudioEngineService] over `just_audio` behind `audio_service`. The
/// player holds the current track and at most the next one, so the next is
/// preloaded and follows without a gap. Nothing touches a plugin before
/// [activate].
final class PluginAudioEngineService implements AudioEngineService {
  static const _permissionChannel = MethodChannel(
    'holyquran/notification_permission',
  );

  final _events = StreamController<EngineEvent>.broadcast();
  final List<StreamSubscription<Object?>> _subscriptions = [];
  AppAudioHandler? _handler;
  Future<void>? _activating;
  double _speed = 1;

  /// The tracks in the player, current first, as the pending playlist
  /// changes leave them.
  List<EngineTrack> _tracks = [];
  Future<void> _playlistChanges = Future.value();
  int _playlist = 0;

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
    final handler = await AudioService.init(
      builder: () => AppAudioHandler(
        (command) => _events.add(RemoteCommandReceived(command)),
      ),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.example.holyquran.playback',
      ),
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
      ..add(player.errorStream.listen((_) => _failed()));
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
    final [current, ...queued] = _tracks;
    _tracks = [current, ?next];
    _inOrder(() async {
      if (queued.isNotEmpty) await _player.removeAudioSourceAt(1);
      if (next != null) await _player.addAudioSource(_source(next));
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
    _tracks = [];
    _playlist++;
    await _handler?.halt();
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
    final generation = ++_playlist;
    _playlistChanges = _setTracks(tracks, from: from)
        .then((_) {
          if (generation == _playlist) then?.call();
        })
        .catchError((Object _) {
          _failed();
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
          _failed();
        });
  }

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  Future<void> seek(Duration position) async =>
      _inOrder(() => _player.seek(position));

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

  Future<void> _setTracks(List<EngineTrack> tracks, {Duration? from}) async {
    try {
      await _player.setAudioSources([
        for (final track in tracks) _source(track),
      ], initialPosition: from);
    } on PlayerInterruptedException {
      // Replaced by a later load.
    } on PlayerException {
      _failed();
    }
  }

  AudioSource _source(EngineTrack track) {
    final file = ProgressiveAudioSource(track.uri);
    if (track.start == null && track.end == null) return file;
    return ClippingAudioSource(child: file, start: track.start, end: track.end);
  }

  // Replacing the playlist is reported as an advance too; only a move from
  // the current track to the next one is.
  void _onDiscontinuity(PositionDiscontinuity discontinuity) {
    if (discontinuity.reason != PositionDiscontinuityReason.autoAdvance ||
        discontinuity.previousEvent.currentIndex != 0 ||
        discontinuity.event.currentIndex != 1 ||
        _tracks.length < 2) {
      return;
    }
    final [ended, ...rest] = _tracks;
    _tracks = rest;
    _events.add(TrackEnded(ended.id));
    _inOrder(() => _player.removeAudioSourceAt(0));
  }

  void _onProcessingState(ProcessingState state) {
    _events.add(
      BufferingChanged(
        state == ProcessingState.loading || state == ProcessingState.buffering,
      ),
    );
    if (state == ProcessingState.completed && _tracks.isNotEmpty) {
      final ended = _tracks.last;
      _tracks = [];
      _events.add(TrackEnded(ended.id));
    }
  }

  // A player failure does not say whether the network caused it (S3), so a
  // streamed track's failure counts as a lost connection.
  void _failed() {
    if (_tracks.isEmpty) return;
    final streamed = _tracks.first.streamed;
    _tracks = [];
    _events.add(
      EngineFailed(
        streamed ? EngineFailure.connection : EngineFailure.playback,
      ),
    );
  }
}
