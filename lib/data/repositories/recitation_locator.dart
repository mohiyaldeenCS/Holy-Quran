import 'package:holyquran/data/repositories/download_settings_repository.dart';
import 'package:holyquran/data/repositories/player_repository.dart';
import 'package:holyquran/data/repositories/recitation_repository.dart';
import 'package:holyquran/domain/models/playback_segment.dart';
import 'package:holyquran/utils/result.dart';

/// The locator the player uses to find a segment's file (`AU-13`, `AU-14`).
/// It looks for the quality the user chose, or the highest the recitation
/// offers; a file of that quality is played from the device when it is
/// there. Failing that, any other quality of it that is on the device whole
/// is played, since the user downloaded it; and only when none is, the
/// chosen quality is streamed. A reciter's own basmala or isti'adha file is
/// not served by [RecitationRepository] yet, so those segments find none.
RecitationFileLocator recitationLocator({
  required RecitationRepository recitations,
  required DownloadSettingsRepository settings,
}) => (recitation, source) async {
  final listed = recitations.recitations
      .where((r) => r.id == recitation.id)
      .firstOrNull;
  if (listed == null) return null;
  final chosen = settings.qualityOf(listed.id);
  final first = chosen != null && listed.qualities.contains(chosen)
      ? chosen
      : listed.qualities.last;
  final order = [
    first,
    ...listed.qualities.reversed.where((quality) => quality != first),
  ];
  RecitationAudio? streamed;
  for (final quality in order) {
    final result = switch (source) {
      AyahFile(:final ayah) => await recitations.ayahFile(
        listed.id,
        ayah,
        qualityKbps: quality,
      ),
      SurahFile(:final surah) || SurahClip(:final surah) =>
        await recitations.surahFile(listed.id, surah, qualityKbps: quality),
      BasmalaFile() || IstiadhaFile() => null,
    };
    switch (result) {
      case null:
        return null;
      case Ok(:final value) when value.local:
        return (uri: value.uri, streamed: false);
      case Ok(:final value):
        streamed ??= value;
      case Failure():
        break;
    }
  }
  return streamed == null ? null : (uri: streamed.uri, streamed: true);
};
