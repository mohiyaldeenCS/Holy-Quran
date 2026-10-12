import 'package:holyquran/data/repositories/quran_index_repository.dart';
import 'package:holyquran/domain/models/division_entry.dart';
import 'package:holyquran/domain/models/edition_map.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/quran_position.dart';
import 'package:holyquran/domain/models/surah_info.dart';

/// An index held in memory. [FakeQuranIndexRepository.synthetic] has the
/// shape of the default synthetic pack of `testing/packs/`: three surahs of
/// 4, 3 and 1 ayat over four pages, with sajdas at 1:2 and 2:3.
final class FakeQuranIndexRepository implements QuranIndexRepository {
  FakeQuranIndexRepository({required this.surahs, required EditionMap map})
    : _map = map,
      riwaya = map.startOf(Division.page, 1).riwaya;

  factory FakeQuranIndexRepository.synthetic() {
    QuranAddress at(int surah, int ayah) => QuranAddress('hafs', surah, ayah);
    return FakeQuranIndexRepository(
      surahs: [
        for (final (number, ayat) in [(1, 4), (2, 3), (3, 1)])
          SurahInfo(
            number: number,
            name: PackText.fromPack('Synthetic surah $number'),
            ayahCount: ayat,
          ),
      ],
      map: EditionMap(
        edition: 'synthetic-edition',
        starts: {
          Division.juz: [at(1, 1), at(2, 1)],
          Division.hizb: [at(1, 1), at(1, 3), at(2, 1), at(3, 1)],
          Division.rub: [
            for (final (surah, ayat) in [(1, 4), (2, 3), (3, 1)])
              for (var ayah = 1; ayah <= ayat; ayah++) at(surah, ayah),
          ],
          Division.page: [at(1, 1), at(1, 4), at(2, 2), at(3, 1)],
        },
        sajdas: {at(1, 2), at(2, 3)},
      ),
    );
  }

  final EditionMap _map;

  @override
  final String riwaya;

  @override
  final List<SurahInfo> surahs;

  @override
  int get surahCount => surahs.length;

  @override
  int ayahCount(int surah) => surahs[surah - 1].ayahCount;

  @override
  int? nextSurah(int surah) => surah < surahCount ? surah + 1 : null;

  @override
  int firstPage(int surah) =>
      _map.numberAt(Division.page, QuranAddress(riwaya, surah, 1));

  @override
  int count(Division division) => _map.count(division);

  @override
  QuranAddress firstAyah(Division division, int number) =>
      _map.startOf(division, number);

  @override
  int numberAt(Division division, QuranAddress address) =>
      _map.numberAt(division, address);

  @override
  List<DivisionEntry> divisions(Division division) => [
    for (var number = 1; number <= count(division); number++)
      DivisionEntry(
        division: division,
        number: number,
        firstAyah: firstAyah(division, number),
        firstPage: numberAt(Division.page, firstAyah(division, number)),
      ),
  ];

  @override
  QuranPosition positionOf(QuranAddress address) => QuranPosition(
    address: address.ayahAddress,
    surah: address.surah,
    juz: numberAt(Division.juz, address),
    hizb: numberAt(Division.hizb, address),
    rub: numberAt(Division.rub, address),
    page: numberAt(Division.page, address),
  );

  @override
  List<DivisionEntry> pageStartsIn(int surah) => [
    for (final page in divisions(Division.page))
      if (page.firstAyah.surah == surah) page,
  ];

  @override
  List<QuranAddress> get sajdas => _map.sajdas.toList()..sort();

  @override
  bool isSajda(QuranAddress address) => _map.isSajda(address);
}
