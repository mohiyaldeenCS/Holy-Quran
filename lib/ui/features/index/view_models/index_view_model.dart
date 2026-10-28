import 'package:flutter/foundation.dart';

import 'package:holyquran/data/repositories/pack_integrity_repository.dart';
import 'package:holyquran/data/repositories/quran_index_repository.dart';
import 'package:holyquran/data/repositories/reading_position_repository.dart';
import 'package:holyquran/domain/models/edition_map.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/surah_info.dart';

enum IndexTab { surahs, juz, hizb }

/// A row of the surah index (`NV-01`).
final class SurahIndexRow {
  const SurahIndexRow({
    required this.info,
    required this.page,
    required this.address,
    required this.lastRead,
  });

  final SurahInfo info;

  /// The page holding the surah's first ayah.
  final int page;

  /// The surah's first ayah, where the row opens the reader.
  final QuranAddress address;

  /// Whether the last position read is in this surah.
  final bool lastRead;
}

/// A row of the juz or hizb index (`NV-02`): unit [number] of [division],
/// the surah and ayah it starts at, and the page of that ayah.
final class DivisionIndexRow {
  const DivisionIndexRow({
    required this.division,
    required this.number,
    required this.surahName,
    required this.address,
    required this.page,
  });

  final Division division;
  final int number;

  /// The name of the surah [address] is in, from the pack.
  final PackText surahName;

  /// The first ayah of the unit, where the row opens the reader.
  final QuranAddress address;
  final int page;

  bool get isRub => division == Division.rub;
}

/// The index screen's state (PRD §8.2, `NV-01`, `NV-02`): the surahs, the juz
/// and the hizb with the rubs that fall inside each. Every count and name
/// comes from the pack's index; while the pack does not serve its surahs, the
/// index shows nothing (PRD §9.5).
final class IndexViewModel extends ChangeNotifier {
  IndexViewModel({required this._index, this._positions, this._integrity}) {
    _positions?.addListener(_changed);
    _integrity?.addListener(_changed);
  }

  final QuranIndexRepository _index;
  final ReadingPositionRepository? _positions;
  final PackIntegrityRepository? _integrity;

  IndexTab _tab = IndexTab.surahs;
  List<DivisionIndexRow>? _juz;
  List<DivisionIndexRow>? _hizb;

  IndexTab get tab => _tab;

  void selectTab(IndexTab tab) {
    if (tab == _tab) return;
    _tab = tab;
    notifyListeners();
  }

  /// Whether the pack serves the surahs the rows are made of.
  bool get hasData => _index.surahs.isNotEmpty;

  int get surahCount => _index.surahs.length;

  int get juzCount => _index.count(Division.juz);

  /// The surahs in order, the last-read one marked.
  List<SurahIndexRow> get surahRows {
    final lastSurah = _lastReadSurah;
    return [
      for (final info in _index.surahs)
        SurahIndexRow(
          info: info,
          page: _index.firstPage(info.number),
          address: QuranAddress(_index.riwaya, info.number, 1),
          lastRead: info.number == lastSurah,
        ),
    ];
  }

  /// The juz in order.
  List<DivisionIndexRow> get juzRows => _juz ??= _rows(Division.juz);

  /// The hizb in order, each followed by the rubs inside it. A rub that starts
  /// where its hizb does is the hizb's row already.
  List<DivisionIndexRow> get hizbRows => _hizb ??= _hizbWithRubs();

  int? get _lastReadSurah {
    final last = _positions?.last;
    if (last == null ||
        last.riwaya != _index.riwaya ||
        last.surah < 1 ||
        last.surah > surahCount) {
      return null;
    }
    return last.surah;
  }

  List<DivisionIndexRow> _rows(Division division) {
    final surahs = _index.surahs;
    return [
      for (final entry in _index.divisions(division))
        if (entry.firstAyah.surah <= surahs.length)
          DivisionIndexRow(
            division: division,
            number: entry.number,
            surahName: surahs[entry.firstAyah.surah - 1].name,
            address: entry.firstAyah,
            page: entry.firstPage,
          ),
    ];
  }

  List<DivisionIndexRow> _hizbWithRubs() {
    final hizb = _rows(Division.hizb);
    final rubsOf = <int, List<DivisionIndexRow>>{};
    for (final rub in _rows(Division.rub)) {
      (rubsOf[_index.numberAt(Division.hizb, rub.address)] ??= []).add(rub);
    }
    return [
      for (final row in hizb) ...[
        row,
        for (final rub in rubsOf[row.number] ?? const <DivisionIndexRow>[])
          if (rub.address != row.address) rub,
      ],
    ];
  }

  void _changed() {
    _juz = null;
    _hizb = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _positions?.removeListener(_changed);
    _integrity?.removeListener(_changed);
    super.dispose();
  }
}
