import 'package:flutter/foundation.dart';

import 'package:holyquran/data/services/daos/reading_position_dao.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/utils/result.dart';

/// The last ayah read on this device (`RD-12`, D-106). Listeners hear of
/// every stored change.
abstract class ReadingPositionRepository extends ChangeNotifier {
  /// The last ayah saved, or null before the first.
  QuranAddress? get last;

  /// Saves [ayah] as the last position. Throws an [ArgumentError] when it is
  /// a word address.
  Future<Result<void>> save(QuranAddress ayah);
}

/// [ReadingPositionRepository] over the user database.
final class LocalReadingPositionRepository extends ReadingPositionRepository {
  LocalReadingPositionRepository._(this._dao, this._now, this._last);

  final ReadingPositionDao _dao;
  final int Function() _now;
  QuranAddress? _last;

  /// Reads the stored position once. A stored address that is not a
  /// canonical ayah address reads as no position.
  static Future<Result<LocalReadingPositionRepository>> load(
    ReadingPositionDao dao, {
    int Function() now = _utcMilliseconds,
  }) async {
    try {
      final stored = await dao.readAddress();
      final parsed = stored == null ? null : QuranAddress.tryParse(stored);
      final last = parsed == null || parsed.isWord ? null : parsed;
      return Ok(LocalReadingPositionRepository._(dao, now, last));
    } on Exception catch (error) {
      return Failure(error);
    }
  }

  static int _utcMilliseconds() => DateTime.now().millisecondsSinceEpoch;

  @override
  QuranAddress? get last => _last;

  @override
  Future<Result<void>> save(QuranAddress ayah) async {
    if (ayah.isWord) {
      throw ArgumentError.value(ayah, 'ayah', 'is a word address');
    }
    if (ayah == _last) return const Ok(null);
    try {
      await _dao.writeAddress(ayah.toString(), updatedAt: _now());
    } on Exception catch (error) {
      return Failure(error);
    }
    _last = ayah;
    notifyListeners();
    return const Ok(null);
  }
}
