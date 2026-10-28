import 'dart:async';

import 'package:flutter/foundation.dart' show ChangeNotifier;

import 'package:holyquran/data/repositories/category_repository.dart';
import 'package:holyquran/data/repositories/note_repository.dart';
import 'package:holyquran/data/repositories/quran_index_repository.dart';
import 'package:holyquran/data/repositories/tag_repository.dart';
import 'package:holyquran/domain/models/category.dart';
import 'package:holyquran/domain/models/note.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/user_tag.dart';
import 'package:holyquran/ui/core/metrics/bookmarks_metrics.dart';
import 'package:holyquran/utils/result.dart';

/// The note sheet's state (`UD-02`, `UD-04`, `UD-07`): the notes the ayah
/// has, one of them or a new one in the editor with its text, category and
/// tags, and the undo of a deletion for [undoShown]. [initialNoteId] opens
/// the sheet on that note once the notes are read.
///
/// The text is the view's controller's; the view reports it to [setBody], and
/// when the model replaces it, [bodyRevision] changes and the view copies
/// [body] into the controller.
final class NoteSheetViewModel extends ChangeNotifier {
  NoteSheetViewModel({
    required QuranAddress address,
    required NoteRepository notes,
    required TagRepository tags,
    required this._categories,
    this._index,
    this._initialNoteId,
    this._undoShown = BookmarksMetrics.undoShown,
  }) : address = address.ayahAddress,
       _notes = notes,
       _tags = tags {
    notes.addListener(_changed);
    tags.addListener(_changed);
    unawaited(_load());
  }

  final QuranAddress address;
  final NoteRepository _notes;
  final TagRepository _tags;
  final CategoryRepository _categories;
  final QuranIndexRepository? _index;
  final Duration _undoShown;
  String? _initialNoteId;

  List<Note> _noteList = const [];
  List<Category> _categoryList = const [];
  List<UserTag> _tagList = const [];
  String? _editingId;
  String _body = '';
  int _bodyRevision = 0;
  String? _categoryId;
  Set<String> _tagIds = const {};
  bool _loaded = false;
  bool _writeFailed = false;
  String? _deletedId;
  Timer? _undoTimer;
  int _reads = 0;
  bool _disposed = false;

  /// The notes on the ayah, older first.
  List<Note> get notes => _noteList;
  List<Category> get categories => _categoryList;

  /// The live tags, by name.
  List<UserTag> get tags => _tagList;

  /// The note in the editor, or null when it holds a new one.
  Note? get editing {
    for (final note in _noteList) {
      if (note.id == _editingId) return note;
    }
    return null;
  }

  String get body => _body;
  int get bodyRevision => _bodyRevision;
  String? get categoryId => _categoryId;
  Set<String> get tagIds => _tagIds;
  bool get loaded => _loaded;

  /// Whether the last save, deletion or undo could not be stored.
  bool get writeFailed => _writeFailed;

  bool get canSave => _body.isNotEmpty;
  bool get canUndo => _deletedId != null;

  /// The name of the ayah's surah in the pack, or null without the index.
  PackText? get surahName {
    final index = _index;
    if (index == null || address.riwaya != index.riwaya) return null;
    final surahs = index.surahs;
    return address.surah >= 1 && address.surah <= surahs.length
        ? surahs[address.surah - 1].name
        : null;
  }

  void setBody(String body) {
    if (body == _body) return;
    _body = body;
    notifyListeners();
  }

  /// Sets the category, or clears it with null.
  void setCategory(String? id) {
    _categoryId = id;
    notifyListeners();
  }

  void toggleTag(String id) {
    _tagIds = _tagIds.contains(id)
        ? ({..._tagIds}..remove(id))
        : {..._tagIds, id};
    notifyListeners();
  }

  /// Makes the tag [name] and chooses it. An empty name does nothing.
  Future<void> addTag(String name) async {
    if (name.isEmpty) return;
    final result = await _tags.create(name);
    if (_disposed) return;
    switch (result) {
      case Ok(:final value):
        _tagIds = {..._tagIds, value.id};
        _writeFailed = false;
      case Failure():
        _writeFailed = true;
    }
    notifyListeners();
  }

  /// Puts [note] in the editor.
  void select(Note note) => _hold(note);

  /// Empties the editor for another note.
  void startNew() => _hold(null);

  /// Saves the note in the editor, making it when it is new. Returns whether
  /// it was stored.
  Future<bool> save() async {
    if (!canSave) return false;
    final tagIds = {
      for (final tag in _tagList)
        if (_tagIds.contains(tag.id)) tag.id,
    };
    final editing = this.editing;
    final Result<Object?> result;
    String? savedId = editing?.id;
    if (editing == null) {
      final added = await _notes.add(
        address,
        _body,
        categoryId: _categoryId,
        tagIds: tagIds,
      );
      if (added case Ok(:final value)) savedId = value.id;
      result = added;
    } else {
      result = await _notes.edit(
        editing.id,
        body: _body,
        categoryId: _categoryId,
        tagIds: tagIds,
      );
    }
    if (_disposed) return false;
    _writeFailed = result is Failure;
    if (result is Ok) _editingId = savedId;
    notifyListeners();
    return result is Ok;
  }

  /// Deletes the note in the editor. It can be brought back by [undo].
  Future<void> delete() async {
    final editing = this.editing;
    if (editing == null) return;
    final result = await _notes.delete(editing.id);
    if (_disposed) return;
    if (result is Failure) {
      _writeFailed = true;
      notifyListeners();
      return;
    }
    _writeFailed = false;
    _deletedId = editing.id;
    _undoTimer?.cancel();
    _undoTimer = Timer(_undoShown, dismissUndo);
    _hold(null);
  }

  /// Brings back the note deleted last.
  Future<void> undo() async {
    final id = _deletedId;
    if (id == null) return;
    dismissUndo();
    final result = await _notes.restore(id);
    if (_disposed || result is! Failure) return;
    _writeFailed = true;
    notifyListeners();
  }

  void dismissUndo() {
    _undoTimer?.cancel();
    _undoTimer = null;
    if (_deletedId == null) return;
    _deletedId = null;
    if (!_disposed) notifyListeners();
  }

  void _hold(Note? note) {
    _editingId = note?.id;
    _body = note?.body ?? '';
    _categoryId = note?.categoryId;
    _tagIds = note?.tagIds ?? const {};
    _bodyRevision++;
    notifyListeners();
  }

  void _changed() => unawaited(_load());

  Future<void> _load() async {
    final read = ++_reads;
    final notes = await _notes.notesAt(address);
    final categories = await _categories.categories();
    final tags = await _tags.tags();
    if (_disposed || read != _reads) return;
    if (notes case Ok(:final value)) _noteList = value;
    if (categories case Ok(:final value)) _categoryList = value;
    if (tags case Ok(:final value)) _tagList = value;
    final first = !_loaded;
    _loaded = true;
    // A note that vanished from the list, as when it is deleted elsewhere,
    // leaves the editor holding a new one.
    if (_editingId != null && editing == null) _editingId = null;
    if (first && _initialNoteId != null) {
      for (final note in _noteList) {
        if (note.id == _initialNoteId) _hold(note);
      }
      _initialNoteId = null;
      return;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _undoTimer?.cancel();
    _notes.removeListener(_changed);
    _tags.removeListener(_changed);
    super.dispose();
  }
}
