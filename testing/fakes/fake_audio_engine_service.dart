import 'dart:async';

import 'package:holyquran/data/services/audio_engine_service.dart';

/// An engine that plays nothing and reports no event, so that a player over
/// it can be started and driven without a plugin.
final class FakeAudioEngineService implements AudioEngineService {
  final _events = StreamController<EngineEvent>.broadcast();

  @override
  Stream<EngineEvent> get events => _events.stream;

  @override
  Future<void> activate() async {}

  @override
  Future<void> play(
    EngineTrack track, {
    EngineTrack? next,
    Duration from = Duration.zero,
  }) async {}

  @override
  Future<void> load(EngineTrack track) async {}

  @override
  Future<void> setNext(EngineTrack? next) async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> setSessionPlaying(bool playing) async {}

  @override
  Future<void> stop() async {}

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
