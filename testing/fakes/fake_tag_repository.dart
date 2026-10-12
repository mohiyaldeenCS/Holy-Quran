import 'package:holyquran/data/repositories/tag_repository.dart';
import 'package:holyquran/domain/models/bookmark.dart';
import 'package:holyquran/domain/models/user_tag.dart';
import 'package:holyquran/utils/result.dart';

/// Tags held in memory for view tests. Every call fails with [failure] when
/// it is set; a restore is never too late. Two live tags never share a
/// name.
final class FakeTagRepository extends TagRepository {
  FakeTagRepository([Iterable<UserTag> tags = const []])
    : _live = {for (final tag in tags) tag.id: tag};

  final Map<String, UserTag> _live;
  final _deleted = <String, UserTag>{};
  Exception? failure;
  var _next = 0;

  @override
  Future<Result<List<UserTag>>> tags() async {
    if (failure case final failure?) return Failure(failure);
    return Ok([..._live.values]..sort((a, b) => a.name.compareTo(b.name)));
  }

  @override
  Future<Result<UserTag>> create(String name) async {
    if (failure case final failure?) return Failure(failure);
    if (name.isEmpty) return const Failure(FormatException('empty name'));
    for (final tag in _live.values) {
      if (tag.name == name) return Ok(tag);
    }
    final tag = UserTag(
      id: 'fake-tag-${_next++}',
      name: name,
      createdAt: DateTime.utc(2026),
    );
    _live[tag.id] = tag;
    notifyListeners();
    return Ok(tag);
  }

  @override
  Future<Result<void>> rename(String id, String name) async {
    if (failure case final failure?) return Failure(failure);
    if (name.isEmpty) return const Failure(FormatException('empty name'));
    final old = _live[id];
    if (old == null) return Failure(ItemNotFound(id));
    if (_taken(name, id)) return Failure(TagNameTaken(name));
    _live[id] = UserTag(id: id, name: name, createdAt: old.createdAt);
    notifyListeners();
    return const Ok(null);
  }

  @override
  Future<Result<void>> delete(String id) => _move(id, _live, _deleted);

  @override
  Future<Result<void>> restore(String id) async {
    if (failure case final failure?) return Failure(failure);
    if (_live.containsKey(id)) return const Ok(null);
    final tag = _deleted[id];
    if (tag != null && _taken(tag.name, id)) {
      return Failure(TagNameTaken(tag.name));
    }
    return _move(id, _deleted, _live);
  }

  bool _taken(String name, String id) =>
      _live.values.any((tag) => tag.name == name && tag.id != id);

  Future<Result<void>> _move(
    String id,
    Map<String, UserTag> from,
    Map<String, UserTag> to,
  ) async {
    if (failure case final failure?) return Failure(failure);
    final tag = from.remove(id);
    if (tag == null) return Failure(ItemNotFound(id));
    to[id] = tag;
    notifyListeners();
    return const Ok(null);
  }
}
