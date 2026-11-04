import 'package:flutter/foundation.dart';

import 'package:holyquran/config/dependencies.dart';
import 'package:holyquran/data/repositories/download_settings_repository.dart';
import 'package:holyquran/data/repositories/listening_position_repository.dart';
import 'package:holyquran/data/repositories/player_repository.dart';
import 'package:holyquran/data/repositories/quran_index_repository.dart';
import 'package:holyquran/data/repositories/recitation_locator.dart';
import 'package:holyquran/data/repositories/recitation_repository.dart';
import 'package:holyquran/data/services/audio_engine_service.dart';
import 'package:holyquran/domain/models/playback_plan_builder.dart';
import 'package:holyquran/domain/use_cases/record_listening_position.dart';
import 'package:holyquran/utils/result.dart';

Future<void> audioProviders(Dependencies dependencies) => provideAudio(
  dependencies,
  createEngine: PluginAudioEngineService.new,
  locate: recitationLocatorOf(dependencies),
);

/// The locator that plays a downloaded file from the device and streams the
/// rest, over the recitations and the download choices earlier areas
/// provided; without them nothing is located.
RecitationFileLocator recitationLocatorOf(Dependencies dependencies) {
  final recitations = dependencies.tryRead<RecitationRepository>();
  final settings = dependencies.tryRead<DownloadSettingsRepository>();
  if (recitations == null || settings == null) {
    return (recitation, source) async => null;
  }
  return recitationLocator(recitations: recitations, settings: settings);
}

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
