import 'dart:async';

import 'package:flutter/foundation.dart' show ChangeNotifier;

import 'package:holyquran/data/repositories/category_repository.dart';
import 'package:holyquran/data/repositories/note_repository.dart';
import 'package:holyquran/data/repositories/pack_integrity_repository.dart';
import 'package:holyquran/data/repositories/quran_index_repository.dart';
import 'package:holyquran/data/repositories/tag_repository.dart';
import 'package:holyquran/domain/models/bookmark.dart';
import 'package:holyquran/domain/models/category.dart';
import 'package:holyquran/domain/models/note.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/user_tag.dart';
import 'package:holyquran/ui/features/bookmarks/view_models/note_drafts.dart';
import 'package:holyquran/utils/result.dart';

/// The note sheet's state (`UD-02`, `UD-04`, `UD-07`): the notes the ayah
/// has, one of them or a new one in the editor with its text, category and
/// tags, and the undo of a deletion. [initialNoteId] opens the sheet on that
/// note once the notes are read.
///
/// The user's text is not lost. While the editor differs from the note it
/// holds (or from nothing, for a new note), another note cannot be chosen;
/// and when the sheet closes the unsaved text is kept in [NoteDrafts], in
/// memory only, and comes back when the sheet is opened again on that note.
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
    this._integrity,
    this._initialNoteId,
    NoteDrafts? drafts,
    Duration window = undoWindow,
  }) : address = address.ayahAddress,
       _notes = notes,
       _tags = tags,
       _drafts = drafts ?? NoteDrafts.session,
       _undoFor = window {
    notes.addListener(_changed);
    tags.addListener(_changed);
    _integrity?.addListener(notifyListeners);
    unawaited(_load());
  }

  final QuranAddress address;
  final NoteRepository _notes;
  final TagRepository _tags;
  final CategoryRepository _categories;
  final QuranIndexRepository? _index;
  final PackIntegrityRepository? _integrity;
  final NoteDrafts _drafts;
  final Duration _undoFor;
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
  bool _saving = false;
  String? _deletedId;
  Timer? _undoTimer;
  int _reads = 0;
  bool _disposed = false;

  /// Whether the undo stays after its time, for a screen-reader or switch
  /// user. It then leaves on the next action, and pressing it once the window
  /// has passed says that the change was not saved. The sheet sets it from the
  /// platform's accessibility setting.
  bool holdUndo = false;

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

  /// Whether the last save, deletion or undo could not be stored.
  bool get writeFailed => _writeFailed;

  // Whitespace alone is no note. The text is stored as typed.
  bool get canSave => _body.trim().isNotEmpty && !_saving;
  bool get canUndo => _deletedId != null;

  /// Whether the editor differs from the note it holds, or from nothing when
  /// it holds a new one.
  bool get dirty {
    final note = editing;
    return _body != (note?.body ?? '') ||
        _categoryId != note?.categoryId ||
        !sameIds(_tagIds, note?.tagIds ?? const {});
  }

  /// Whether another note can be chosen, or a new one started: not while the
  /// text typed would be lost.
  bool get canSwitch => !dirty;

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

  /// Makes the tag [name] and chooses it. An empty name does nothing. The tag
  /// is known at once, without waiting for the tags to be read again.
  Future<void> addTag(String name) async {
    if (name.isEmpty) return;
    final result = await _tags.create(name);
    if (_disposed) return;
    switch (result) {
      case Ok(:final value):
        if (_tagList.every((tag) => tag.id != value.id)) {
          _tagList = [..._tagList, value]
            ..sort((a, b) => a.name.compareTo(b.name));
        }
        _tagIds = {..._tagIds, value.id};
        _writeFailed = false;
      case Failure():
        _writeFailed = true;
    }
    notifyListeners();
  }

  /// Puts [note] in the editor, unless that would lose the text typed.
  void select(Note note) {
    if (dirty) return;
    _dismissUndo(notify: false);
    _hold(note);
  }

  /// Empties the editor for another note, unless that would lose the text
  /// typed.
  void startNew() {
    if (dirty) return;
    _dismissUndo(notify: false);
    _hold(null);
  }

  /// Saves the note in the editor, making it when it is new. Returns whether
  /// it was stored.
  Future<bool> save() async {
    if (!canSave) return false;
    _saving = true;
    _dismissUndo(notify: false);
    notifyListeners();
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
    _saving = false;
    _writeFailed = result is Failure;
    if (result is Ok) {
      _drafts.drop(address, editing?.id);
      _editingId = savedId;
      // The note is in the list before the editor is let go of, so that it
      // does not look unsaved.
      await _load();
      if (_disposed) return true;
    }
    notifyListeners();
    return result is Ok;
  }

  /// Deletes the note in the editor. It can be brought back by [undo]. A note
  /// that is gone already counts as deleted.
  Future<void> delete() async {
    final editing = this.editing;
    if (editing == null) return;
    final startedAt = DateTime.now();
    final result = await _notes.delete(editing.id);
    if (_disposed) return;
    if (result case Failure(error: ItemNotFound())) {
      _drafts.drop(address, editing.id);
      _hold(null);
      return;
    }
    if (result is Failure) {
      _writeFailed = true;
      notifyListeners();
      return;
    }
    _writeFailed = false;
    _drafts.drop(address, editing.id);
    _deletedId = editing.id;
    _undoTimer?.cancel();
    // The window runs from the write, which came after [startedAt].
    _undoTimer = Timer(
      _undoFor - DateTime.now().difference(startedAt),
      _undoTimeUp,
    );
    _hold(null);
  }

  /// Brings back the note deleted last. It fails, and says so, once the
  /// repository's window has passed.
  Future<void> undo() async {
    final id = _deletedId;
    if (id == null) return;
    _dismissUndo(notify: false);
    final result = await _notes.restore(id);
    if (_disposed) return;
    _writeFailed = result is Failure;
    notifyListeners();
  }

  void _undoTimeUp() {
    if (!holdUndo) _dismissUndo();
  }

  void _dismissUndo({bool notify = true}) {
    _undoTimer?.cancel();
    _undoTimer = null;
    if (_deletedId == null) return;
    _deletedId = null;
    if (notify && !_disposed) notifyListeners();
  }

  // The editor takes [note], or an unsaved draft of it when there is one.
  void _hold(Note? note) {
    final draft = _drafts.of(address, note?.id);
    _editingId = note?.id;
    _body = draft?.body ?? note?.body ?? '';
    _categoryId = draft != null ? draft.categoryId : note?.categoryId;
    _tagIds = draft?.tagIds ?? note?.tagIds ?? const {};
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
    if (first) {
      final initial = _initialNoteId;
      _initialNoteId = null;
      _hold(_noteList.where((note) => note.id == initial).firstOrNull);
      return;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    if (_loaded) {
      if (dirty) {
        _drafts.keep(
          address,
          _editingId,
          NoteDraft(body: _body, categoryId: _categoryId, tagIds: _tagIds),
        );
      } else {
        _drafts.drop(address, _editingId);
      }
    }
    _disposed = true;
    _undoTimer?.cancel();
    _integrity?.removeListener(notifyListeners);
    _notes.removeListener(_changed);
    _tags.removeListener(_changed);
    super.dispose();
  }
}
