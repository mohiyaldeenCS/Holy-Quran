import '../../testing/packs/synthetic_pack.dart';

/// [defaultSyntheticSurahs] with the words and marks of every ayah found as
/// D-078 finds them: tokens between spaces, a word when it holds a letter.
/// The default list splits one token of ayah 2:3 into two words at a
/// hyphen, a gap that docs/CONTENT_PACKS.md, "Word and mark offsets", does
/// not allow, so the integrity suite runs on this list.
final List<SyntheticSurah> formatSyntheticSurahs = [
  for (final surah in defaultSyntheticSurahs)
    SyntheticSurah(
      name: surah.name,
      basmala: surah.basmala,
      revelationPlace: surah.revelationPlace,
      revelationOrder: surah.revelationOrder,
      ayat: [for (final ayah in surah.ayat) SyntheticAyah(ayah.text)],
    ),
];

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
