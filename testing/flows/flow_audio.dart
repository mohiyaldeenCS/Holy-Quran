import 'dart:async';

import 'package:holyquran/data/repositories/player_repository.dart';
import 'package:holyquran/data/services/audio_engine_service.dart';
import 'package:holyquran/domain/models/playback_segment.dart';
import 'package:holyquran/domain/models/recitation.dart';

/// Where [flowLocator] puts every file; nothing is ever fetched from it.
const flowAudioHost = 'audio.invalid';

/// The name of the file a segment plays, such as `ayah-hafs-1-2`.
String audioNameOf(PlaybackSource source) => switch (source) {
  AyahFile(:final ayah) => 'ayah-${ayah.riwaya}-${ayah.surah}-${ayah.ayah}',
  SurahFile(:final surah) || SurahClip(:final surah) => 'surah-$surah',
  BasmalaFile() => 'basmala',
  IstiadhaFile() => 'istiadha',
};

/// Finds a streamed file for every segment, with the name [audioNameOf]
/// gives it.
Future<LocatedAudio?> flowLocator(
  Recitation recitation,
  PlaybackSource source,
) async => (
  uri: Uri.parse('https://$flowAudioHost/${audioNameOf(source)}'),
  streamed: true,
);

/// The name of the file [track] plays.
String audioNameOfTrack(EngineTrack track) => track.uri.pathSegments.last;

/// An engine that plays nothing and keeps what it was told: [heard] holds
/// every file it started, in order, once. A test ends the track that plays
/// with [finish], as the device would at its end, and the engine goes on to
/// the next track it was given, with no gap.
final class RecordingEngine implements AudioEngineService {
  final _events = StreamController<EngineEvent>.broadcast();

  /// The name of every file the listener heard, in order.
  final heard = <String>[];

  EngineTrack? _current;
  EngineTrack? _next;
  var _held = false;

  /// The name of the file that plays now, or null.
  String? get playing => _current == null ? null : audioNameOfTrack(_current!);

  /// The name of the file queued after the one that plays, or null.
  String? get queued => _next == null ? null : audioNameOfTrack(_next!);

  @override
  Stream<EngineEvent> get events => _events.stream;

  /// Ends the track that plays and starts the next one, if any.
  void finish() {
    final ended = _current;
    if (ended == null) throw StateError('nothing plays');
    _current = _next;
    _next = null;
    if (_current case final track?) heard.add(audioNameOfTrack(track));
    _events.add(TrackEnded(ended.id));
  }

  @override
  Future<void> activate() async {}

  @override
  Future<void> play(
    EngineTrack track, {
    EngineTrack? next,
    Duration from = Duration.zero,
  }) async {
    _current = track;
    _next = next;
    _held = false;
    heard.add(audioNameOfTrack(track));
  }

  @override
  Future<void> load(EngineTrack track) async {
    _current = track;
    _next = null;
    _held = true;
  }

  @override
  Future<void> setNext(EngineTrack? next) async => _next = next;

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {
    if (_held && _current != null) heard.add(audioNameOfTrack(_current!));
    _held = false;
  }

  @override
  Future<void> setSessionPlaying(bool playing) async {}

  @override
  Future<void> stop() async {
    _current = null;
    _next = null;
    _held = false;
  }

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setSpeed(double factor) async {}

  @override
  Future<void> setMediaInfo(MediaInfo info) async {}

  @override
  Future<void> dispose() => _events.close();
}
