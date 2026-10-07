import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import 'continuity_log.dart';
import 'tone_wav.dart';

const spikeTrackLength = Duration(minutes: 5, seconds: 50);
const spikeTrackCount = 12;
const _toneFileName = 'spike-s3-tone.wav';
const _doubleClickWindow = Duration(milliseconds: 400);

Future<SpikeAudioHandler>? _spikeAudio;

/// Starts the media service once; only the spike entry calls this.
Future<SpikeAudioHandler> initSpikeAudio() => _spikeAudio ??= AudioService.init(
  builder: SpikeAudioHandler.new,
  config: const AudioServiceConfig(
    androidNotificationChannelId: 'com.example.holyquran.spike.audio',
    androidNotificationChannelName: 'Spike playback',
    androidNotificationOngoing: true,
  ),
);

/// Writes the tone to the cache directory once and reuses it afterwards.
Future<File> spikeToneFile() async {
  final file = File('${(await getTemporaryDirectory()).path}/$_toneFileName');
  final size = toneWavSize(length: spikeTrackLength);
  if (await file.exists() && await file.length() == size) return file;
  final bytes = await Isolate.run(() => toneWav(length: spikeTrackLength));
  await file.writeAsBytes(bytes, flush: true);
  return file;
}

/// The engine-service shape carried to M1.9: one just_audio player behind the
/// OS media session, with audio focus and media buttons handled here.
class SpikeAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  SpikeAudioHandler() {
    _subscriptions.add(
      _player.playbackEventStream.listen(
        _broadcast,
        onError: (Object _) => _event('player-error'),
      ),
    );
    _subscriptions.add(_player.currentIndexStream.listen(_announceItem));
    _subscriptions.add(
      _player.processingStateStream.listen((state) {
        if (state == ProcessingState.completed) {
          _event('completed');
          unawaited(_player.pause());
        }
      }),
    );
    unawaited(_configureSession());
  }

  final _player = AudioPlayer(handleInterruptions: false);
  final _events = StreamController<String>.broadcast();
  final List<StreamSubscription<Object?>> _subscriptions = [];
  bool _pausedByInterruption = false;
  int _clicks = 0;
  Timer? _clickTimer;

  /// Names of commands, media buttons and audio-session events, in order.
  Stream<String> get events => _events.stream;

  PlayerProbe probe() => (
    position: _player.position,
    playing: _player.playing,
    state: _player.processingState.name,
    track: _player.currentIndex ?? -1,
  );

  Future<void> loadTone(File tone) async {
    final items = [
      for (var i = 1; i <= spikeTrackCount; i++)
        MediaItem(
          id: 'tone-$i',
          title: 'Tone $i of $spikeTrackCount',
          album: 'S3 spike',
          duration: spikeTrackLength,
        ),
    ];
    await updateQueue(items);
    await _player.setAudioSources([
      for (var i = 0; i < spikeTrackCount; i++) AudioSource.file(tone.path),
    ]);
  }

  @override
  Future<void> play() {
    _event('play');
    _pausedByInterruption = false;
    return _player.play();
  }

  @override
  Future<void> pause() {
    _event('pause');
    return _player.pause();
  }

  @override
  Future<void> stop() async {
    _event('stop');
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) {
    _event('seek');
    return _player.seek(position);
  }

  @override
  Future<void> skipToNext() {
    _event('skip-next');
    return super.skipToNext();
  }

  @override
  Future<void> skipToPrevious() {
    _event('skip-previous');
    return super.skipToPrevious();
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= queue.value.length) return;
    await _player.seek(Duration.zero, index: index);
  }

  @override
  Future<void> click([MediaButton button = MediaButton.media]) async {
    if (button != MediaButton.media) {
      _event('click-${button.name}');
      return super.click(button);
    }
    _clicks++;
    _clickTimer?.cancel();
    _clickTimer = Timer(_doubleClickWindow, _resolveClicks);
  }

  Future<void> dispose() async {
    _clickTimer?.cancel();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _player.dispose();
    await _events.close();
  }

  void _resolveClicks() {
    final clicks = _clicks;
    _clicks = 0;
    if (clicks == 1) {
      _event('click-single');
      unawaited(_player.playing ? pause() : play());
    } else {
      _event('click-double');
      unawaited(skipToNext());
    }
  }

  Future<void> _configureSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
    _subscriptions.add(
      session.becomingNoisyEventStream.listen((_) {
        _event('noisy');
        unawaited(pause());
      }),
    );
    _subscriptions.add(session.interruptionEventStream.listen(_interrupted));
  }

  // Speech pauses rather than ducks; it resumes only after a transient loss
  // that the system ends with a focus gain.
  void _interrupted(AudioInterruptionEvent event) {
    _event('interruption-${event.begin ? 'begin' : 'end'}-${event.type.name}');
    if (event.begin) {
      if (_player.playing) {
        unawaited(_player.pause());
        _pausedByInterruption = event.type != AudioInterruptionType.unknown;
      }
      return;
    }
    if (_pausedByInterruption && event.type != AudioInterruptionType.unknown) {
      _pausedByInterruption = false;
      unawaited(_player.play());
    }
  }

  void _announceItem(int? index) {
    final items = queue.value;
    if (index == null || index >= items.length) return;
    mediaItem.add(items[index]);
    _event('track-$index');
  }

  void _event(String name) {
    if (!_events.isClosed) _events.add(name);
  }

  void _broadcast(PlaybackEvent event) {
    final playing = _player.playing;
    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
          MediaControl.skipToNext,
        ],
        systemActions: const {MediaAction.seek},
        androidCompactActionIndices: const [0, 1, 3],
        processingState: switch (_player.processingState) {
          ProcessingState.idle => AudioProcessingState.idle,
          ProcessingState.loading => AudioProcessingState.loading,
          ProcessingState.buffering => AudioProcessingState.buffering,
          ProcessingState.ready => AudioProcessingState.ready,
          ProcessingState.completed => AudioProcessingState.completed,
        },
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: event.currentIndex,
      ),
    );
  }
}
