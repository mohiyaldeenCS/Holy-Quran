import 'package:flutter/foundation.dart';

import 'package:holyquran/data/services/daos/tag_dao.dart';
import 'package:holyquran/data/services/user_database.dart';
import 'package:holyquran/domain/models/bookmark.dart';
import 'package:holyquran/domain/models/user_tag.dart';
import 'package:holyquran/utils/result.dart';

/// The free tags shared by bookmarks and notes (`UD-02`, `UD-07`). A deleted
/// tag disappears from every bookmark and note until it is restored.
/// Listeners hear of every stored change.
abstract class TagRepository extends ChangeNotifier {
  /// The live tags, by name.
  Future<Result<List<UserTag>>> tags();

  /// The live tag named exactly [name], made when there is none. Fails with
  /// a [FormatException] when [name] is empty.
  Future<Result<UserTag>> create(String name);

  /// Fails with a [FormatException] when [name] is empty, and with
  /// [TagNameTaken] when another live tag has it.
  Future<Result<void>> rename(String id, String name);

  /// Marks tag [id] deleted; [restore] undoes it within [undoWindow].
  Future<Result<void>> delete(String id);

  /// Fails with [UndoExpired] after [undoWindow], and with [TagNameTaken]
  /// when a live tag has its name since.
  Future<Result<void>> restore(String id);
}

/// [TagRepository] over the user database.
final class LocalTagRepository extends TagRepository {
  LocalTagRepository(this._dao, {this._now = _utcMilliseconds});

  final TagDao _dao;
  final int Function() _now;

  static int _utcMilliseconds() => DateTime.now().millisecondsSinceEpoch;

  @override
  Future<Result<List<UserTag>>> tags() => _read(
    () async =>
        [for (final row in await _dao.live()) _tag(row)]
          ..sort((a, b) => a.name.compareTo(b.name)),
  );

  @override
  Future<Result<UserTag>> create(String name) async {
    final found = await _read(() {
      _checkName(name);
      return _dao.liveNamed(name);
    });
    switch (found) {
      case Ok(value: [final existing, ...]):
        return Ok(_tag(existing));
      case Failure(:final error):
        return Failure(error);
      case Ok():
    }
    return _change(() async => _tag(await _dao.named(name, at: _now())));
  }

  @override
  Future<Result<void>> rename(String id, String name) => _change(() async {
    _checkName(name);
    await _checkFree(name, id);
    if (!await _dao.rename(id, name, at: _now())) throw ItemNotFound(id);
  });

  @override
  Future<Result<void>> delete(String id) => _change(() async {
    if (!await _dao.markDeleted(id, at: _now())) throw ItemNotFound(id);
  });

  @override
  Future<Result<void>> restore(String id) async {
    final TagRow? row;
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
      await _checkFree(row.name, id);
      await _dao.revive(id, at: now);
    });
  }

  Future<void> _checkFree(String name, String id) async {
    if ((await _dao.liveNamed(name)).any((tag) => tag.id != id)) {
      throw TagNameTaken(name);
    }
  }

  static void _checkName(String name) {
    if (name.isEmpty) throw const FormatException('A tag name is empty');
  }

  static UserTag _tag(TagRow row) => UserTag(
    id: row.id,
    name: row.name,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt, isUtc: true),
  );

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
