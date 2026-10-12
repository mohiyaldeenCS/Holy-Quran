import 'package:flutter/foundation.dart';

import 'package:holyquran/data/repositories/pack_integrity_repository.dart';
import 'package:holyquran/data/repositories/quran_index_repository.dart';
import 'package:holyquran/data/repositories/reading_position_repository.dart';
import 'package:holyquran/domain/models/edition_map.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/quran_address.dart';

/// Where «أكمل القراءة» leads: the last ayah read, its surah's name from
/// the pack, and its place in the mushaf.
final class ContinueReading {
  const ContinueReading({
    required this.address,
    required this.surahName,
    required this.page,
    required this.juz,
    required this.progress,
  });

  final QuranAddress address;
  final PackText surahName;
  final int page;
  final int juz;

  /// The page over the edition's page count.
  final double progress;
}

/// The home screen's state (PRD §7.1, M1.2). A repository is absent while
/// the app has no base pack or no user database. A pack that fails stops
/// serving its surah names, which [integrity] announces (PRD §9.5).
final class HomeViewModel extends ChangeNotifier {
  HomeViewModel({this._positions, this._index, this._integrity}) {
    _positions?.addListener(notifyListeners);
    _integrity?.addListener(notifyListeners);
  }

  final ReadingPositionRepository? _positions;
  final QuranIndexRepository? _index;
  final PackIntegrityRepository? _integrity;

  /// The continue-reading card, or null when there is no position yet, no
  /// verified pack serving its surah names, or the position is not an ayah
  /// of that pack.
  ContinueReading? get continueReading {
    final address = _positions?.last;
    final index = _index;
    if (address == null || index == null) return null;
    final surahs = index.surahs;
    if (address.riwaya != index.riwaya ||
        address.surah < 1 ||
        address.surah > surahs.length ||
        address.ayah < 1 ||
        address.ayah > surahs[address.surah - 1].ayahCount) {
      return null;
    }
    final position = index.positionOf(address);
    return ContinueReading(
      address: position.address,
      surahName: surahs[address.surah - 1].name,
      page: position.page,
      juz: position.juz,
      progress: position.page / index.count(Division.page),
    );
  }

  @override
  void dispose() {
    _positions?.removeListener(notifyListeners);
    _integrity?.removeListener(notifyListeners);
    super.dispose();
  }
}
