import '../../domain/models/division_entry.dart';
import '../../domain/models/edition_map.dart';
import '../../domain/models/pack_failure.dart';
import '../../domain/models/quran_address.dart';
import '../../domain/models/quran_position.dart';
import '../../domain/models/quran_structure.dart';
import '../../domain/models/surah_info.dart';
import '../../utils/result.dart';

/// The surahs, divisions and sajdas of the base pack, read once and then
/// answered synchronously. A number or address outside the edition throws
/// a [RangeError] or an [ArgumentError], as [QuranStructure] says.
abstract interface class QuranIndexRepository implements QuranStructure {
  /// Every surah with its facts, in order; none while the pack serves no
  /// text (PRD section 9.5). The numbers below stay answered.
  List<SurahInfo> get surahs;

  /// The page holding the first ayah of [surah].
  int firstPage(int surah);

  /// Every juz, hizb, rub or page, in order.
  List<DivisionEntry> divisions(Division division);

  QuranPosition positionOf(QuranAddress address);

  /// The pages whose first ayah is in [surah], in order: the page breaks
  /// inside it, and its first page when that starts at its first ayah.
  List<DivisionEntry> pageStartsIn(int surah);

  /// The ayat carrying a sajda, in order.
  List<QuranAddress> get sajdas;

  bool isSajda(QuranAddress address);
}

/// The index of a text pack, built from its surahs and edition map.
final class PackQuranIndexRepository implements QuranIndexRepository {
  PackQuranIndexRepository._(
    this.riwaya,
    this._map,
    List<SurahInfo> infos,
    this._serving,
  ) : _ayahCounts = [for (final info in infos) info.ayahCount] {
    _entries = {
      for (final division in Division.values)
        division: List.unmodifiable([
          for (var number = 1; number <= _map.count(division); number++)
            _entry(division, number),
        ]),
    };
    _surahs = List.unmodifiable(infos);
    sajdas = List.unmodifiable(_map.sajdas.toList()..sort());
    final pageStarts = <int, List<DivisionEntry>>{};
    for (final page in _entries[Division.page]!) {
      (pageStarts[page.firstAyah.surah] ??= []).add(page);
    }
    _pageStarts = {
      for (final MapEntry(:key, :value) in pageStarts.entries)
        key: List.unmodifiable(value),
    };
  }

  /// The index of the [surahs] and edition [map] of a pack in [riwaya].
  /// Its surahs, which hold the names, are listed while [serving] is true.
  /// A map in which some division is missing or does not start at the first
  /// ayah fails with [PackInconsistent], as every ayah must have a position.
  static Result<PackQuranIndexRepository> build({
    required String riwaya,
    required List<SurahInfo> surahs,
    required EditionMap map,
    required bool Function() serving,
  }) {
    final first = QuranAddress(riwaya, 1, 1);
    for (final division in Division.values) {
      if (surahs.isEmpty ||
          map.count(division) == 0 ||
          map.startOf(division, 1) != first) {
        return Failure(
          PackInconsistent(
            map.edition,
            '${division.name} 1 does not start at the first ayah',
          ),
        );
      }
    }
    return Ok(PackQuranIndexRepository._(riwaya, map, surahs, serving));
  }

  @override
  final String riwaya;

  final EditionMap _map;
  final List<int> _ayahCounts;
  late final Map<Division, List<DivisionEntry>> _entries;
  late final Map<int, List<DivisionEntry>> _pageStarts;

  final bool Function() _serving;
  late final List<SurahInfo> _surahs;

  @override
  late final List<QuranAddress> sajdas;

  @override
  List<SurahInfo> get surahs => _serving() ? _surahs : const [];

  DivisionEntry _entry(Division division, int number) {
    final firstAyah = _map.startOf(division, number);
    return DivisionEntry(
      division: division,
      number: number,
      firstAyah: firstAyah,
      firstPage: _map.numberAt(Division.page, firstAyah),
    );
  }

  @override
  int get surahCount => _ayahCounts.length;

  @override
  int ayahCount(int surah) {
    RangeError.checkValueInInterval(surah, 1, surahCount, 'surah');
    return _ayahCounts[surah - 1];
  }

  @override
  int? nextSurah(int surah) {
    RangeError.checkValueInInterval(surah, 1, surahCount, 'surah');
    return surah < surahCount ? surah + 1 : null;
  }

  @override
  int firstPage(int surah) {
    RangeError.checkValueInInterval(surah, 1, surahCount, 'surah');
    return _map.numberAt(Division.page, QuranAddress(riwaya, surah, 1));
  }

  @override
  int count(Division division) => _map.count(division);

  @override
  QuranAddress firstAyah(Division division, int number) =>
      _map.startOf(division, number);

  @override
  int numberAt(Division division, QuranAddress address) {
    _check(address);
    return _map.numberAt(division, address);
  }

  @override
  List<DivisionEntry> divisions(Division division) => _entries[division]!;

  @override
  QuranPosition positionOf(QuranAddress address) {
    _check(address);
    return QuranPosition(
      address: address.ayahAddress,
      surah: address.surah,
      juz: _map.numberAt(Division.juz, address),
      hizb: _map.numberAt(Division.hizb, address),
      rub: _map.numberAt(Division.rub, address),
      page: _map.numberAt(Division.page, address),
    );
  }

  @override
  List<DivisionEntry> pageStartsIn(int surah) {
    RangeError.checkValueInInterval(surah, 1, surahCount, 'surah');
    return _pageStarts[surah] ?? const [];
  }

  @override
  bool isSajda(QuranAddress address) => _map.isSajda(address);

  void _check(QuranAddress address) {
    if (address.riwaya != riwaya ||
        address.surah > surahCount ||
        address.ayah > _ayahCounts[address.surah - 1]) {
      throw ArgumentError.value(address, 'address', 'is not in the edition');
    }
  }
}
