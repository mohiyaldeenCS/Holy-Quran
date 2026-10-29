import 'package:flutter/foundation.dart';

import 'package:holyquran/config/dependencies.dart';
import 'package:holyquran/data/repositories/listening_position_repository.dart';
import 'package:holyquran/data/repositories/player_repository.dart';
import 'package:holyquran/data/repositories/quran_index_repository.dart';
import 'package:holyquran/data/services/audio_engine_service.dart';
import 'package:holyquran/domain/models/playback_plan_builder.dart';
import 'package:holyquran/domain/use_cases/record_listening_position.dart';
import 'package:holyquran/utils/result.dart';

Future<void> audioProviders(Dependencies dependencies) => provideAudio(
  dependencies,
  createEngine: PluginAudioEngineService.new,
  // No recitation pack can be installed or streamed before P1-13 and P1-33,
  // which bring the locator.
  locate: (recitation, source) async => null,
);

/// Provides the [PlayerRepository] over the engine [createEngine] makes. Plans are
/// built over the base pack's edition, so without a verified base pack,
/// which provides the index and the [PlaybackPlanBuilder] together, there is
/// nothing to play and no player is provided: the builder is provided
/// whenever the player is. Media metadata names the surah from the index.
/// Where listening stops is kept in the [ListeningPositionRepository], when
/// the user-data area provides one (`AU-16`).
Future<void> provideAudio(
  Dependencies dependencies, {
  required AudioEngineService Function() createEngine,
  required RecitationFileLocator locate,
}) async {
  final index = dependencies.tryRead<QuranIndexRepository>();
  if (index == null || dependencies.tryRead<PlaybackPlanBuilder>() == null) {
    return;
  }
  final player = EnginePlayerRepository(
    engine: createEngine(),
    locate: locate,
    surahName: (surah) async =>
        index.surahs.where((info) => info.number == surah).firstOrNull?.name,
  );
  dependencies.provideListenable<PlayerRepository>(player);
  if (dependencies.tryRead<ListeningPositionRepository>()
      case final positions?) {
    _recordListening(player, positions);
  }
}

// The recorder lives as long as the app, like the player it listens to.
void _recordListening(
  PlayerRepository player,
  ListeningPositionRepository positions,
) {
  final recorder = RecordListeningPosition(
    save: (position) async {
      if (await positions.save(position) case Failure(:final error)) {
        FlutterError.reportError(
          FlutterErrorDetails(exception: error, library: 'listening position'),
        );
      }
    },
  );
  player.addListener(() => recorder.update(player.state));
}
