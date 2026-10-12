import 'package:holyquran/domain/models/edition_map.dart';
import 'package:holyquran/domain/models/quran_address.dart';

import 'surah_text.dart';

/// The reference pages that begin inside [surah], as ayah number to page
/// number (`RD-06`). A page that begins at the surah's first ayah has no
/// boundary inside the text, so it is left out.
Map<int, int> pageStartsIn(EditionMap map, String riwaya, int surah) => {
  for (final (index, start) in _starts(map, Division.page, riwaya, surah))
    if (start.ayah > 1) start.ayah: index + 1,
};

/// The margin marks of [surah] (`RD-02`, `RD-15`): at each ayah that starts a
/// juz, a hizb or a rub, one mark for the largest of them, and one at each
/// sajda.
List<MarginMark> marginMarksIn(EditionMap map, String riwaya, int surah) {
  final juz = {
    for (final (index, start) in _starts(map, Division.juz, riwaya, surah))
      start.ayah: index + 1,
  };
  final hizb = {
    for (final (index, start) in _starts(map, Division.hizb, riwaya, surah))
      start.ayah: index + 1,
  };
  final rub = {
    for (final (_, start) in _starts(map, Division.rub, riwaya, surah))
      start.ayah,
  };
  int hizbAt(int ayah) =>
      map.numberAt(Division.hizb, QuranAddress(riwaya, surah, ayah));
  final ayat = {...juz.keys, ...hizb.keys, ...rub}.toList()..sort();
  return [
    for (final ayah in ayat)
      if (juz[ayah] case final number?)
        MarginMark(MarginMarkKind.juz, ayah, juz: number)
      else if (hizb[ayah] case final number?)
        MarginMark(MarginMarkKind.hizb, ayah, hizb: number)
      else
        MarginMark(MarginMarkKind.rub, ayah, hizb: hizbAt(ayah)),
    for (final sajda in map.sajdas.toList()..sort())
      if (sajda.riwaya == riwaya && sajda.surah == surah)
        MarginMark(MarginMarkKind.sajda, sajda.ayah),
  ];
}

Iterable<(int, QuranAddress)> _starts(
  EditionMap map,
  Division division,
  String riwaya,
  int surah,
) sync* {
  for (var number = 1; number <= map.count(division); number++) {
    final start = map.startOf(division, number);
    if (start.riwaya == riwaya && start.surah == surah) {
      yield (number - 1, start);
    }
  }
}
