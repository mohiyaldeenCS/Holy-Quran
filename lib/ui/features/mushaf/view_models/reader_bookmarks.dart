import 'dart:async';

import 'package:flutter/foundation.dart' hide Category;

import 'package:holyquran/data/repositories/bookmark_repository.dart';
import 'package:holyquran/data/repositories/category_repository.dart';
import 'package:holyquran/domain/models/bookmark.dart';
import 'package:holyquran/domain/models/category.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/utils/result.dart';

/// The user's bookmarks as the reader needs them (`UD-05`, `UD-01`): the
/// category of each bookmarked ayah, for the margin ribbons, and the two-tap
/// bookmark (D-128, 8). Without both repositories it is unavailable, and the
/// reader offers no bookmark.
///
/// A bookmark made here takes the category of the newest bookmark, which is
/// the last one used, and «حفظ» when there is none. Removing a bookmark can
/// be undone while the user stays on the same ayah and for [undoWindow]
/// (`UD-07`). What the user did shows at once, from the result of the
/// action; the stored list is read again when the repository says it changed.
/// An action the store refused sets [failed], which the toolbar says in words;
/// it clears with the next action that works, or when the selection moves.
final class ReaderBookmarks extends ChangeNotifier {
  ReaderBookmarks({this._bookmarks, this._categories}) {
    _bookmarks?.addListener(_changed);
  }

  final BookmarkRepository? _bookmarks;
  final CategoryRepository? _categories;
  Map<String, Category> _categoryById = const {};
  Map<QuranAddress, Bookmark> _live = const {};
  String? _lastCategoryId;
  String? _memoriseId;
  Bookmark? _removed;
  Timer? _undoExpiry;
  bool _busy = false;
  bool _failed = false;
  bool _disposed = false;

  /// The category of each bookmarked ayah, replaced whenever it changes.
  final ValueNotifier<Map<QuranAddress, BuiltinCategory>> ribbons =
      ValueNotifier(const {});

  bool get available => _bookmarks != null && _categories != null;

  /// Whether the last action was refused by the store.
  bool get failed => _failed;

  /// Whether [ayah] has a live bookmark.
  bool has(QuranAddress ayah) => _live.containsKey(ayah);

  /// Whether the bookmark just removed from [ayah] can be restored.
  bool canUndoAt(QuranAddress ayah) => _removed?.address == ayah;

  Future<void> load() async {
    if (_bookmarks == null || _categories == null) return;
    await _loadCategories();
    await _reload();
  }

  Future<void> _loadCategories() async {
    if (await _categories!.categories() case Ok(:final value)) {
      _categoryById = {for (final c in value) c.id: c};
      _memoriseId = value
          .where((c) => c.builtin == BuiltinCategory.memorise)
          .firstOrNull
          ?.id;
    }
  }

  void _changed() => unawaited(_reload());

  Future<void> _reload() async {
    final result = await _bookmarks?.list();
    if (_disposed) return;
    if (result case Ok(:final value)) {
      _live = {for (final b in value) b.address: b};
      _lastCategoryId = value.firstOrNull?.categoryId;
      _publish();
      notifyListeners();
    }
  }

  void _publish() {
    ribbons.value = {
      for (final b in _live.values)
        if (_categoryById[b.categoryId] case final category?)
          b.address: category.builtin,
    };
  }

  /// Bookmarks [ayah], or removes the bookmark it has. A second call while
  /// the first has not finished is ignored.
  Future<void> toggle(QuranAddress ayah) async {
    final bookmarks = _bookmarks;
    if (bookmarks == null || _busy) return;
    _busy = true;
    try {
      final existing = _live[ayah];
      if (existing != null) {
        await _remove(bookmarks, existing);
      } else {
        await _add(bookmarks, ayah);
      }
    } finally {
      _busy = false;
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> _add(BookmarkRepository bookmarks, QuranAddress ayah) async {
    // A category list that failed to load once is read again.
    if (_lastCategoryId == null && _memoriseId == null) {
      await _loadCategories();
    }
    final category = _lastCategoryId ?? _memoriseId;
    if (category == null) {
      _failed = true;
      return;
    }
    _clearUndo();
    switch (await bookmarks.add(ayah, category)) {
      case Ok(:final value):
        _failed = false;
        _live = {..._live, ayah: value};
        _lastCategoryId = value.categoryId;
        _publish();
      case Failure():
        _failed = true;
    }
  }

  Future<void> _remove(BookmarkRepository bookmarks, Bookmark existing) async {
    switch (await bookmarks.delete(existing.id)) {
      case Ok():
        _failed = false;
        _live = {..._live}..remove(existing.address);
        _publish();
        _removed = existing;
        _undoExpiry?.cancel();
        _undoExpiry = Timer(undoWindow, () {
          _removed = null;
          if (!_disposed) notifyListeners();
        });
      case Failure():
        _failed = true;
    }
  }

  /// Puts back the bookmark [toggle] removed last.
  Future<void> undo() async {
    final removed = _removed;
    final bookmarks = _bookmarks;
    if (removed == null || bookmarks == null || _busy) return;
    _busy = true;
    _clearUndo();
    try {
      switch (await bookmarks.restore(removed.id)) {
        case Ok():
          _failed = false;
          _live = {..._live, removed.address: removed};
          _publish();
        case Failure():
          _failed = true;
      }
    } finally {
      _busy = false;
    }
    if (!_disposed) notifyListeners();
  }

  /// The selection moved: the undo and the notice belong to the ayah they
  /// were for.
  void leave() {
    if (_removed == null && !_failed) return;
    _clearUndo();
    _failed = false;
    notifyListeners();
  }

  void _clearUndo() {
    _undoExpiry?.cancel();
    _undoExpiry = null;
    _removed = null;
  }

  @override
  void dispose() {
    _disposed = true;
    _undoExpiry?.cancel();
    _bookmarks?.removeListener(_changed);
    ribbons.dispose();
    super.dispose();
  }
}
