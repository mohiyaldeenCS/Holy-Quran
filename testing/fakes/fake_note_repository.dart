import 'package:holyquran/data/repositories/note_repository.dart';
import 'package:holyquran/domain/models/bookmark.dart';
import 'package:holyquran/domain/models/note.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/utils/result.dart';

/// Notes held in memory for view tests. Every call fails with [failure] when
/// it is set; a restore is never too late. Searches look in [tagNames].
final class FakeNoteRepository extends NoteRepository {
  FakeNoteRepository({
    Iterable<Note> notes = const [],
    this.tagNames = const {},
  }) : _live = {for (final note in notes) note.id: note};

  final Map<String, Note> _live;
  final _deleted = <String, Note>{};
  Map<String, String> tagNames;
  Exception? failure;
  var _next = 0;

  @override
  Future<Result<Note>> add(
    QuranAddress ayah,
    String body, {
    String? categoryId,
    Set<String> tagIds = const {},
  }) async {
    if (failure case final failure?) return Failure(failure);
    if (body.isEmpty) return const Failure(FormatException('empty body'));
    final time = DateTime.utc(2026).add(Duration(seconds: _next));
    final note = Note(
      id: 'fake-note-${_next++}',
      address: ayah,
      body: body,
      categoryId: categoryId,
      tagIds: tagIds,
      createdAt: time,
      updatedAt: time,
    );
    _live[note.id] = note;
    notifyListeners();
    return Ok(note);
  }

  @override
  Future<Result<void>> edit(
    String id, {
    required String body,
    required String? categoryId,
    required Set<String> tagIds,
  }) async {
    if (failure case final failure?) return Failure(failure);
    if (body.isEmpty) return const Failure(FormatException('empty body'));
    final old = _live[id];
    if (old == null) return Failure(ItemNotFound(id));
    _live[id] = Note(
      id: id,
      address: old.address,
      body: body,
      categoryId: categoryId,
      tagIds: tagIds,
      createdAt: old.createdAt,
      updatedAt: old.updatedAt,
    );
    notifyListeners();
    return const Ok(null);
  }

  @override
  Future<Result<List<Note>>> notesAt(QuranAddress ayah) async {
    if (failure case final failure?) return Failure(failure);
    return Ok(
      [
        for (final note in _live.values)
          if (note.address == ayah) note,
      ]..sort(ListOrder.mushaf.compare),
    );
  }

  @override
  Future<Result<Set<QuranAddress>>> annotatedAyat() async => failure == null
      ? Ok({for (final note in _live.values) note.address})
      : Failure(failure!);

  @override
  Future<Result<void>> delete(String id) => _move(id, _live, _deleted);

  @override
  Future<Result<void>> restore(String id) async =>
      _live.containsKey(id) && failure == null
      ? const Ok(null)
      : _move(id, _deleted, _live);

  @override
  Future<Result<List<Note>>> list({
    ListOrder order = ListOrder.newest,
    String? categoryId,
    String? tagId,
    String query = '',
  }) async {
    if (failure case final failure?) return Failure(failure);
    return Ok(
      [
        for (final note in _live.values)
          if (note.matches(
            categoryId: categoryId,
            tagId: tagId,
            query: query,
            tagNames: tagNames,
          ))
            note,
      ]..sort(order.compare),
    );
  }

  Future<Result<void>> _move(
    String id,
    Map<String, Note> from,
    Map<String, Note> to,
  ) async {
    if (failure case final failure?) return Failure(failure);
    final note = from.remove(id);
    if (note == null) return Failure(ItemNotFound(id));
    to[id] = note;
    notifyListeners();
    return const Ok(null);
  }
}
