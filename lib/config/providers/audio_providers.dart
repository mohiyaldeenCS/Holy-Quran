import 'package:holyquran/config/dependencies.dart';
import 'package:holyquran/data/repositories/player_repository.dart';
import 'package:holyquran/data/repositories/quran_index_repository.dart';
import 'package:holyquran/data/services/audio_engine_service.dart';

/// Plans are built over the base pack's edition, so without a verified base
/// pack there is nothing to play and no player is provided.
Future<void> audioProviders(Dependencies dependencies) async {
  final index = _indexOrNull(dependencies);
  if (index == null) return;
  provideAudio(
    dependencies,
    engine: PluginAudioEngineService(),
    index: index,
    // No recitation pack can be installed or streamed before P1-13 and
    // P1-33, which bring the locator.
    locate: (recitation, source) async => null,
  );
}

/// Provides the [PlayerRepository] over [engine]; media metadata names the
/// surah from [index].
void provideAudio(
  Dependencies dependencies, {
  required AudioEngineService engine,
  required QuranIndexRepository index,
  required RecitationFileLocator locate,
}) {
  dependencies.provideListenable<PlayerRepository>(
    EnginePlayerRepository(
      engine: engine,
      locate: locate,
      surahName: (surah) async =>
          index.surahs.where((info) => info.number == surah).firstOrNull?.name,
    ),
  );
}

// The Quran area provides the index only once the base pack is verified.
QuranIndexRepository? _indexOrNull(Dependencies dependencies) {
  try {
    return dependencies.read<QuranIndexRepository>();
  } on StateError {
    return null;
  }
}
