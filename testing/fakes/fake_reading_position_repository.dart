import 'package:holyquran/data/repositories/reading_position_repository.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/utils/result.dart';

/// An in-memory [ReadingPositionRepository] for view and widget tests.
/// Remembers every save in [saved].
final class FakeReadingPositionRepository extends ReadingPositionRepository {
  FakeReadingPositionRepository({this.last});

  @override
  QuranAddress? last;

  final List<QuranAddress> saved = [];

  @override
  Future<Result<void>> save(QuranAddress ayah) async {
    if (ayah.isWord) {
      throw ArgumentError.value(ayah, 'ayah', 'is a word address');
    }
    saved.add(ayah);
    if (ayah != last) {
      last = ayah;
      notifyListeners();
    }
    return const Ok(null);
  }
}
