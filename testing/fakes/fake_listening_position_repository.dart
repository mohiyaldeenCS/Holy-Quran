import 'package:holyquran/data/repositories/listening_position_repository.dart';
import 'package:holyquran/domain/models/listening_position.dart';
import 'package:holyquran/utils/result.dart';

/// An in-memory [ListeningPositionRepository] for view tests. Remembers
/// every save in [saved].
final class FakeListeningPositionRepository
    extends ListeningPositionRepository {
  FakeListeningPositionRepository({this.last});

  @override
  ListeningPosition? last;

  final List<ListeningPosition> saved = [];

  @override
  Future<Result<void>> save(ListeningPosition position) async {
    saved.add(position);
    if (position != last) {
      last = position;
      notifyListeners();
    }
    return const Ok(null);
  }
}
