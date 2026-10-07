import '../../testing/packs/synthetic_pack.dart';

/// [surahs] with the ayat of surah [number] replaced by [ayat].
List<SyntheticSurah> withAyat(
  List<SyntheticSurah> surahs,
  int number,
  List<SyntheticAyah> ayat,
) => [
  for (final (index, surah) in surahs.indexed)
    if (index + 1 != number)
      surah
    else
      SyntheticSurah(
        name: surah.name,
        basmala: surah.basmala,
        revelationPlace: surah.revelationPlace,
        revelationOrder: surah.revelationOrder,
        ayat: ayat,
      ),
];
