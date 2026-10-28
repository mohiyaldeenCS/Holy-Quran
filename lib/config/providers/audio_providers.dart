import 'package:holyquran/config/dependencies.dart';
import 'package:holyquran/data/repositories/player_repository.dart';
import 'package:holyquran/data/repositories/quran_index_repository.dart';
import 'package:holyquran/data/services/audio_engine_service.dart';
import 'package:holyquran/domain/models/playback_plan_builder.dart';

Future<void> audioProviders(Dependencies dependencies) => provideAudio(
  dependencies,
  engine: PluginAudioEngineService.new,
  // No recitation pack can be installed or streamed before P1-13 and P1-33,
  // which bring the locator.
  locate: (recitation, source) async => null,
);

/// Provides the [PlayerRepository] over the engine [engine] makes. Plans are
/// built over the base pack's edition, so without a verified base pack,
/// which provides the index and the [PlaybackPlanBuilder] together, there is
/// nothing to play and no player is provided: the builder is provided
/// whenever the player is. Media metadata names the surah from the index.
Future<void> provideAudio(
  Dependencies dependencies, {
  required AudioEngineService Function() engine,
  required RecitationFileLocator locate,
}) async {
  final index = _providedOrNull<QuranIndexRepository>(dependencies);
  if (index == null ||
      _providedOrNull<PlaybackPlanBuilder>(dependencies) == null) {
    return;
  }
  dependencies.provideListenable<PlayerRepository>(
    EnginePlayerRepository(
      engine: engine(),
      locate: locate,
      surahName: (surah) async =>
          index.surahs.where((info) => info.number == surah).firstOrNull?.name,
    ),
  );
}

// The Quran area provides these only once the base pack is verified.
T? _providedOrNull<T extends Object>(Dependencies dependencies) {
  try {
    return dependencies.read<T>();
  } on StateError {
    return null;
  }
}
