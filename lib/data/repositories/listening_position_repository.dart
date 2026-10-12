import 'package:flutter/foundation.dart';

import 'package:holyquran/data/services/daos/listening_position_dao.dart';
import 'package:holyquran/domain/models/listening_position.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/utils/result.dart';

/// Where listening last stopped on this device (`AU-16`, D-106). The player
/// decides how often to save. Listeners hear of every stored change.
abstract class ListeningPositionRepository extends ChangeNotifier {
  /// The last position saved, or null before the first.
  ListeningPosition? get last;

  Future<Result<void>> save(ListeningPosition position);
}

/// [ListeningPositionRepository] over the user database.
final class LocalListeningPositionRepository
    extends ListeningPositionRepository {
  LocalListeningPositionRepository._(this._dao, this._now, this._last);

  final ListeningPositionDao _dao;
  final int Function() _now;
  ListeningPosition? _last;

  /// Reads the stored position once. A stored row that is not a canonical
  /// ayah address with an offset of zero or more reads as no position.
  static Future<Result<LocalListeningPositionRepository>> load(
    ListeningPositionDao dao, {
    int Function() now = _utcMilliseconds,
  }) async {
    try {
      final row = await dao.read();
      final address = row == null ? null : QuranAddress.tryParse(row.address);
      final last =
          row == null ||
              address == null ||
              address.isWord ||
              row.offsetMs.isNegative
          ? null
          : ListeningPosition(
              address: address,
              recitationId: row.recitationId,
              offset: Duration(milliseconds: row.offsetMs),
            );
      return Ok(LocalListeningPositionRepository._(dao, now, last));
    } on Exception catch (error) {
      return Failure(error);
    }
  }

  static int _utcMilliseconds() => DateTime.now().millisecondsSinceEpoch;

  @override
  ListeningPosition? get last => _last;

  @override
  Future<Result<void>> save(ListeningPosition position) async {
    if (position == _last) return const Ok(null);
    try {
      await _dao.write(
        position.address.toString(),
        position.recitationId,
        position.offset.inMilliseconds,
        updatedAt: _now(),
      );
    } on Exception catch (error) {
      return Failure(error);
    }
    _last = position;
    notifyListeners();
    return const Ok(null);
  }
}
