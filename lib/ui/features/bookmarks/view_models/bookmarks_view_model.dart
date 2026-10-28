import 'dart:async';

import 'package:flutter/foundation.dart' show ChangeNotifier;

import 'package:holyquran/data/repositories/bookmark_repository.dart';
import 'package:holyquran/data/repositories/category_repository.dart';
import 'package:holyquran/data/repositories/note_repository.dart';
import 'package:holyquran/data/repositories/quran_index_repository.dart';
import 'package:holyquran/data/repositories/quran_text_repository.dart';
import 'package:holyquran/data/repositories/tag_repository.dart';
import 'package:holyquran/domain/models/bookmark.dart';
import 'package:holyquran/domain/models/category.dart';
import 'package:holyquran/domain/models/note.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/user_tag.dart';
import 'package:holyquran/ui/core/metrics/bookmarks_metrics.dart';
import 'package:holyquran/utils/result.dart';

/// The two lists of the screen.
enum AnnotationTab { bookmarks, notes }

/// One bookmark or note in a list, with what the pack gives for its ayah.
/// [ayahText] and [surahName] are null while the app has no base pack, or
/// the pack lacks the ayah.
final class AnnotationEntry {
  const AnnotationEntry({
    required this.id,
    required this.address,
    required this.categoryId,
    required this.tagIds,
    this.note,
    this.ayahText,
    this.surahName,
  });

  final String id;
  final QuranAddress address;
  final String? categoryId;
  final Set<String> tagIds;

  /// The text of a note; null for a bookmark.
  final String? note;
  final PackText? ayahText;
  final PackText? surahName;
}

/// What was deleted last, which [BookmarksViewModel.undo] brings back.
final class _Deleted {
  const _Deleted(this.tab, this.id);

  final AnnotationTab tab;
  final String id;
}

/// The state of the bookmarks and notes screen (`UD-03`, `UD-07`, `SR-08`):
/// the list of the tab chosen, in the order chosen, filtered by category and
/// tag and by what was typed, each with the ayah's text from the pack. A
/// deletion can be undone for [undoShown]. The lists are read again whenever
/// a repository tells of a change, and a read that a newer one has replaced
/// is dropped.
final class BookmarksViewModel extends ChangeNotifier {
  BookmarksViewModel({
    required BookmarkRepository bookmarks,
    required NoteRepository notes,
    required TagRepository tags,
    required this._categories,
    this._text,
    this._index,
    this._undoShown = BookmarksMetrics.undoShown,
  }) : _bookmarks = bookmarks,
       _notes = notes,
       _tags = tags {
    for (final source in [bookmarks, notes, tags]) {
      source.addListener(_changed);
    }
    unawaited(_load());
  }

  final BookmarkRepository _bookmarks;
  final NoteRepository _notes;
  final TagRepository _tags;
  final CategoryRepository _categories;
  final QuranTextRepository? _text;
  final QuranIndexRepository? _index;
  final Duration _undoShown;

  AnnotationTab _tab = AnnotationTab.bookmarks;
  ListOrder _order = ListOrder.newest;
  String? _categoryId;
  String? _tagId;
  String _query = '';
  List<Category> _categoryList = const [];
  List<UserTag> _tagList = const [];
  List<AnnotationEntry> _entries = const [];
  AnnotationTab _entriesTab = AnnotationTab.bookmarks;
  bool _loaded = false;
  bool _failed = false;
  bool _writeFailed = false;
  _Deleted? _deleted;
  Timer? _undoTimer;
  int _reads = 0;
  bool _disposed = false;
  final _ayahTexts = <QuranAddress, PackText?>{};

  AnnotationTab get tab => _tab;
  ListOrder get order => _order;
  String? get categoryId => _categoryId;
  String? get tagId => _tagId;
  String get query => _query;

  /// The categories to filter by, in the order of [BuiltinCategory].
  List<Category> get categories => _categoryList;

  /// The live tags, by name.
  List<UserTag> get tags => _tagList;

  /// The list of the tab chosen, as the filter and the query leave it; empty
  /// until the tab's first read, so that one tab's cards never show as the
  /// other's.
  List<AnnotationEntry> get entries =>
      _entriesTab == _tab ? _entries : const [];

  /// Whether the list of the tab chosen has been read, rightly or not.
  bool get loaded => _loaded && _entriesTab == _tab;

  /// Whether the last read of the list failed.
  bool get failed => _failed;

  /// Whether the last deletion or undo could not be stored.
  bool get writeFailed => _writeFailed;

  /// Whether the list is cut down by a filter or a query, so that an empty
  /// list is not the same as having nothing.
  bool get narrowed =>
      _categoryId != null || _tagId != null || _query.isNotEmpty;

  /// Whether a deletion can still be undone.
  bool get canUndo => _deleted != null;

  /// The built-in category with [id], or null for none or an unknown one.
  BuiltinCategory? categoryOf(String? id) {
    for (final category in _categoryList) {
      if (category.id == id) return category.builtin;
    }
    return null;
  }

  /// The name of the live tag with [id], or null when it is deleted.
  String? tagName(String id) {
    for (final tag in _tagList) {
      if (tag.id == id) return tag.name;
    }
    return null;
  }

  void selectTab(AnnotationTab tab) => _narrow(() => _tab = tab);

  void selectOrder(ListOrder order) => _narrow(() => _order = order);

  /// Pressing the chosen category again clears the filter.
  void toggleCategory(String id) =>
      _narrow(() => _categoryId = _categoryId == id ? null : id);

  void toggleTag(String id) => _narrow(() => _tagId = _tagId == id ? null : id);

  void search(String query) => _narrow(() => _query = query);

  void _narrow(void Function() change) {
    change();
    _writeFailed = false;
    notifyListeners();
    unawaited(_load());
  }

  /// Puts bookmark [id] in [categoryId] (D-128, 8: the user changes the
  /// category a bookmark was made in from this list).
  Future<void> setCategory(String id, String categoryId) =>
      _store(_bookmarks.setCategory(id, categoryId));

  /// Makes [tagIds] the tags of bookmark [id].
  Future<void> setTags(String id, Set<String> tagIds) =>
      _store(_bookmarks.setTags(id, tagIds));

  /// Makes the tag [name], or finds the one named so; returns its id, or null
  /// when it could not be stored.
  Future<String?> createTag(String name) async {
    final result = await _tags.create(name);
    if (_disposed) return null;
    switch (result) {
      case Ok(:final value):
        return value.id;
      case Failure():
        _writeFailed = true;
        notifyListeners();
        return null;
    }
  }

  Future<void> _store(Future<Result<void>> write) async {
    final result = await write;
    if (_disposed || result is! Failure) return;
    _writeFailed = true;
    notifyListeners();
  }

  /// Deletes [entry] of the tab shown. It can be brought back by [undo].
  Future<void> delete(AnnotationEntry entry) async {
    final tab = _tab;
    final result = switch (tab) {
      AnnotationTab.bookmarks => await _bookmarks.delete(entry.id),
      AnnotationTab.notes => await _notes.delete(entry.id),
    };
    if (_disposed) return;
    if (result is Failure) {
      _writeFailed = true;
      notifyListeners();
      return;
    }
    _writeFailed = false;
    _deleted = _Deleted(tab, entry.id);
    _undoTimer?.cancel();
    _undoTimer = Timer(_undoShown, dismissUndo);
    notifyListeners();
  }

  /// Brings back what was deleted last.
  Future<void> undo() async {
    final deleted = _deleted;
    if (deleted == null) return;
    dismissUndo();
    final result = switch (deleted.tab) {
      AnnotationTab.bookmarks => await _bookmarks.restore(deleted.id),
      AnnotationTab.notes => await _notes.restore(deleted.id),
    };
    if (_disposed || result is! Failure) return;
    _writeFailed = true;
    notifyListeners();
  }

  /// Stops offering the undo of the last deletion.
  void dismissUndo() {
    _undoTimer?.cancel();
    _undoTimer = null;
    if (_deleted == null) return;
    _deleted = null;
    if (!_disposed) notifyListeners();
  }

  void _changed() => unawaited(_load());

  Future<void> _load() async {
    final read = ++_reads;
    final categories = await _categories.categories();
    final tags = await _tags.tags();
    final tab = _tab;
    final entries = switch (tab) {
      AnnotationTab.bookmarks => await _readBookmarks(),
      AnnotationTab.notes => await _readNotes(),
    };
    if (_disposed || read != _reads) return;
    if (categories case Ok(:final value)) _categoryList = value;
    if (tags case Ok(:final value)) _tagList = value;
    _failed = entries == null;
    _entries = entries ?? const [];
    _entriesTab = tab;
    _loaded = true;
    notifyListeners();
  }

  Future<List<AnnotationEntry>?> _readBookmarks() async {
    final result = await _bookmarks.list(
      order: _order,
      categoryId: _categoryId,
      tagId: _tagId,
      query: _query,
    );
    if (result is! Ok<List<Bookmark>>) return null;
    return [
      for (final bookmark in result.value)
        await _entry(
          id: bookmark.id,
          address: bookmark.address,
          categoryId: bookmark.categoryId,
          tagIds: bookmark.tagIds,
        ),
    ];
  }

  Future<List<AnnotationEntry>?> _readNotes() async {
    final result = await _notes.list(
      order: _order,
      categoryId: _categoryId,
      tagId: _tagId,
      query: _query,
    );
    if (result is! Ok<List<Note>>) return null;
    return [
      for (final note in result.value)
        await _entry(
          id: note.id,
          address: note.address,
          categoryId: note.categoryId,
          tagIds: note.tagIds,
          note: note.body,
        ),
    ];
  }

  Future<AnnotationEntry> _entry({
    required String id,
    required QuranAddress address,
    required String? categoryId,
    required Set<String> tagIds,
    String? note,
  }) async => AnnotationEntry(
    id: id,
    address: address,
    categoryId: categoryId,
    tagIds: tagIds,
    note: note,
    ayahText: await _ayahText(address),
    surahName: _surahName(address),
  );

  Future<PackText?> _ayahText(QuranAddress address) async {
    final text = _text;
    if (text == null || address.riwaya != text.riwaya) return null;
    if (_ayahTexts.containsKey(address)) return _ayahTexts[address];
    final read = await text.ayahText(address);
    return _ayahTexts[address] = switch (read) {
      Ok(:final value) => value,
      Failure() => null,
    };
  }

  PackText? _surahName(QuranAddress address) {
    final surahs = _index?.surahs;
    if (surahs == null || address.riwaya != _index!.riwaya) return null;
    return address.surah >= 1 && address.surah <= surahs.length
        ? surahs[address.surah - 1].name
        : null;
  }

  @override
  void dispose() {
    _disposed = true;
    _undoTimer?.cancel();
    for (final source in [_bookmarks, _notes, _tags]) {
      source.removeListener(_changed);
    }
    super.dispose();
  }
}
