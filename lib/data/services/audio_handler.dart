import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

import 'audio_engine_service.dart';

/// The OS media session over one player, ported from spike S3: the lock
/// screen, the notification, headset buttons and the audio session send
/// their commands to [onCommand] and never act on the player themselves, so
/// the player repository stays the one authority (`AU-15`, `AU-22`).
final class AppAudioHandler extends BaseAudioHandler with SeekHandler {
  AppAudioHandler(this.onCommand) {
    _subscriptions.add(player.playbackEventStream.listen(_broadcast));
    unawaited(_configureSession());
  }

  /// One click toggles, two or more within this window skip (S3).
  static const _clickWindow = Duration(milliseconds: 400);

  final void Function(RemoteCommand command) onCommand;
  final player = AudioPlayer(handleInterruptions: false);
  final List<StreamSubscription<Object?>> _subscriptions = [];
  bool _pausedByInterruption = false;
  int _clicks = 0;
  Timer? _clickTimer;

  @override
  Future<void> play() async {
    _pausedByInterruption = false;
    onCommand(const RemotePlay());
  }

  @override
  Future<void> pause() async => onCommand(const RemotePause());

  @override
  Future<void> stop() async => onCommand(const RemoteStop());

  @override
  Future<void> seek(Duration position) async => onCommand(RemoteSeek(position));

  @override
  Future<void> skipToNext() async => onCommand(const RemoteNext());

  @override
  Future<void> skipToPrevious() async => onCommand(const RemotePrevious());

  @override
  Future<void> click([MediaButton button = MediaButton.media]) async {
    if (button != MediaButton.media) return super.click(button);
    _clicks++;
    _clickTimer?.cancel();
    _clickTimer = Timer(_clickWindow, _resolveClicks);
  }

  /// Stops the player and ends the media session's foreground state.
  Future<void> halt() async {
    await player.stop();
    await super.stop();
  }

  /// The pack's surah name is shown whole and unchanged (D-114); without it
  /// the reciter's name stands alone.
  void show(MediaInfo info) {
    final name = info.surahName;
    mediaItem.add(
      MediaItem(
        id: '${info.reciter}/${name.hashCode}',
        title: name == null ? info.reciter : name.verbatim,
        artist: name == null ? null : info.reciter,
      ),
    );
  }

  Future<void> dispose() async {
    _clickTimer?.cancel();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await player.dispose();
  }

  void _resolveClicks() {
    final clicks = _clicks;
    _clicks = 0;
    if (clicks == 1) {
      onCommand(player.playing ? const RemotePause() : const RemotePlay());
    } else {
      onCommand(const RemoteNext());
    }
  }

  Future<void> _configureSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
    _subscriptions
      ..add(
        session.becomingNoisyEventStream.listen(
          (_) => onCommand(const RemotePause()),
        ),
      )
      ..add(session.interruptionEventStream.listen(_interrupted));
  }

  // Recitation pauses rather than ducks, and resumes only after a transient
  // loss that the system ends (S3).
  void _interrupted(AudioInterruptionEvent event) {
    if (event.begin) {
      if (player.playing) {
        _pausedByInterruption = event.type != AudioInterruptionType.unknown;
        onCommand(const RemotePause());
      }
      return;
    }
    if (_pausedByInterruption && event.type != AudioInterruptionType.unknown) {
      onCommand(const RemotePlay());
    }
    _pausedByInterruption = false;
  }

  void _broadcast(PlaybackEvent event) {
    final playing = player.playing;
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
        processingState: switch (player.processingState) {
          ProcessingState.idle => AudioProcessingState.idle,
          ProcessingState.loading => AudioProcessingState.loading,
          ProcessingState.buffering => AudioProcessingState.buffering,
          ProcessingState.ready => AudioProcessingState.ready,
          ProcessingState.completed => AudioProcessingState.completed,
        },
        playing: playing,
        updatePosition: player.position,
        bufferedPosition: player.bufferedPosition,
        speed: player.speed,
      ),
    );
  }
}
