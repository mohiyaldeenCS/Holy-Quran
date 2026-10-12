import 'package:flutter/foundation.dart';

import 'package:holyquran/data/services/daos/note_dao.dart';
import 'package:holyquran/data/services/user_database.dart';
import 'package:holyquran/domain/models/bookmark.dart';
import 'package:holyquran/domain/models/note.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/utils/result.dart';

/// The user's notes on ayat (`UD-04`, `UD-03`, `UD-07`, `SR-08`). Listeners
/// hear of every stored change.
abstract class NoteRepository extends ChangeNotifier {
  /// Adds a note on [ayah]; an ayah may have several. Fails with a
  /// [FormatException] when [body] is empty. Throws an [ArgumentError] when
  /// [ayah] is a word address.
  Future<Result<Note>> add(
    QuranAddress ayah,
    String body, {
    String? categoryId,
    Set<String> tagIds = const {},
  });

  /// Sets every field the user edits of note [id]; a null [categoryId]
  /// clears its category. Fails with a [FormatException] when [body] is
  /// empty.
  Future<Result<void>> edit(
    String id, {
    required String body,
    required String? categoryId,
    required Set<String> tagIds,
  });

  /// The live notes of [ayah], older first. Throws an [ArgumentError] when it
  /// is a word address.
  Future<Result<List<Note>>> notesAt(QuranAddress ayah);

  /// The ayat that have a live note, for the margin marks (`UD-05`).
  Future<Result<Set<QuranAddress>>> annotatedAyat();

  /// Marks note [id] deleted; [restore] undoes it within [undoWindow].
  Future<Result<void>> delete(String id);

  /// Fails with [UndoExpired] after [undoWindow].
  Future<Result<void>> restore(String id);

  /// The live notes in [order], in [categoryId] and tagged [tagId] when they
  /// are given, whose body or a tag's name contains [query] when it is not
  /// empty.
  Future<Result<List<Note>>> list({
    ListOrder order = ListOrder.newest,
    String? categoryId,
    String? tagId,
    String query = '',
  });
}

/// [NoteRepository] over the user database.
final class LocalNoteRepository extends NoteRepository {
  LocalNoteRepository(this._dao, {this._now = _utcMilliseconds});

  final NoteDao _dao;
  final int Function() _now;

  static int _utcMilliseconds() => DateTime.now().millisecondsSinceEpoch;

  @override
  Future<Result<Note>> add(
    QuranAddress ayah,
    String body, {
    String? categoryId,
    Set<String> tagIds = const {},
  }) {
    _checkAyah(ayah);
    return _change(() async {
      _checkBody(body);
      final row = await _dao.add(
        ayah.toString(),
        body,
        categoryId: categoryId,
        tagIds: tagIds,
        at: _now(),
      );
      return _note(row, await _tagsOf(row.id))!;
    });
  }

  @override
  Future<Result<void>> edit(
    String id, {
    required String body,
    required String? categoryId,
    required Set<String> tagIds,
  }) => _change(() async {
    _checkBody(body);
    final edited = await _dao.edit(
      id,
      body: body,
      categoryId: categoryId,
      tagIds: tagIds,
      at: _now(),
    );
    if (!edited) throw ItemNotFound(id);
  });

  @override
  Future<Result<List<Note>>> notesAt(QuranAddress ayah) {
    _checkAyah(ayah);
    return _read(() async {
      final rows = await _dao.liveAt(ayah.toString());
      return [for (final row in rows) ?_note(row, await _tagsOf(row.id))]
        ..sort(ListOrder.mushaf.compare);
    });
  }

  @override
  Future<Result<Set<QuranAddress>>> annotatedAyat() => _read(
    () async => {for (final row in await _dao.live()) ?_ayah(row.address)},
  );

  @override
  Future<Result<void>> delete(String id) => _change(() async {
    if (!await _dao.markDeleted(id, at: _now())) throw ItemNotFound(id);
  });

  @override
  Future<Result<void>> restore(String id) async {
    final NoteRow? row;
    switch (await _read(() => _dao.byId(id))) {
      case Ok(:final value):
        row = value;
      case Failure(:final error):
        return Failure(error);
    }
    if (row != null && !row.deleted) return const Ok(null);
    return _change(() async {
      if (row == null) throw ItemNotFound(id);
      final now = _now();
      if (now - row.updatedAt > undoWindow.inMilliseconds) {
        throw UndoExpired(id);
      }
      await _dao.revive(id, at: now);
    });
  }

  @override
  Future<Result<List<Note>>> list({
    ListOrder order = ListOrder.newest,
    String? categoryId,
    String? tagId,
    String query = '',
  }) => _read(() async {
    final tagIds = <String, Set<String>>{};
    final tagNames = <String, String>{};
    for (final (noteId, tag) in await _dao.liveTags()) {
      tagIds.putIfAbsent(noteId, () => {}).add(tag.id);
      tagNames[tag.id] = tag.name;
    }
    return [
      for (final row in await _dao.live())
        if (_note(row, tagIds[row.id] ?? const {}) case final note?
            when note.matches(
              categoryId: categoryId,
              tagId: tagId,
              query: query,
              tagNames: tagNames,
            ))
          note,
    ]..sort(order.compare);
  });

  Future<Set<String>> _tagsOf(String id) async => {
    for (final (_, tag) in await _dao.liveTags(noteId: id)) tag.id,
  };

  static void _checkAyah(QuranAddress ayah) {
    if (ayah.isWord) {
      throw ArgumentError.value(ayah, 'ayah', 'is a word address');
    }
  }

  static void _checkBody(String body) {
    if (body.isEmpty) throw const FormatException('A note body is empty');
  }

  /// A stored address that is not a canonical ayah address reads as no
  /// note.
  static QuranAddress? _ayah(String stored) {
    final parsed = QuranAddress.tryParse(stored);
    return parsed == null || parsed.isWord ? null : parsed;
  }

  static Note? _note(NoteRow row, Set<String> tagIds) {
    final ayah = _ayah(row.address);
    if (ayah == null) return null;
    return Note(
      id: row.id,
      address: ayah,
      body: row.body,
      categoryId: row.categoryId,
      tagIds: tagIds,
      createdAt: _time(row.createdAt),
      updatedAt: _time(row.updatedAt),
    );
  }

  static DateTime _time(int ms) =>
      DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);

  static Future<Result<T>> _read<T>(Future<T> Function() read) async {
    try {
      return Ok(await read());
    } on Exception catch (error) {
      return Failure(error);
    }
  }

  Future<Result<T>> _change<T>(Future<T> Function() change) async {
    final result = await _read(change);
    if (result is Ok<T>) notifyListeners();
    return result;
  }
}
