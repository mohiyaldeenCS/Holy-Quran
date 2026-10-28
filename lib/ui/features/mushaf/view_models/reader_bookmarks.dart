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
/// be undone while the user stays on the same ayah (`UD-07`).
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
  bool _disposed = false;

  /// The category of each bookmarked ayah, replaced whenever it changes.
  final ValueNotifier<Map<QuranAddress, BuiltinCategory>> ribbons =
      ValueNotifier(const {});

  bool get available => _bookmarks != null && _categories != null;

  /// Whether [ayah] has a live bookmark.
  bool has(QuranAddress ayah) => _live.containsKey(ayah);

  /// Whether the bookmark just removed from [ayah] can be restored.
  bool canUndoAt(QuranAddress ayah) => _removed?.address == ayah;

  Future<void> load() async {
    final categories = _categories;
    if (categories == null || _bookmarks == null) return;
    if (await categories.categories() case Ok(:final value)) {
      _categoryById = {for (final c in value) c.id: c};
      _memoriseId = value
          .where((c) => c.builtin == BuiltinCategory.memorise)
          .firstOrNull
          ?.id;
    }
    await _reload();
  }

  void _changed() => unawaited(_reload());

  Future<void> _reload() async {
    final bookmarks = _bookmarks;
    if (bookmarks == null) return;
    final result = await bookmarks.list();
    if (_disposed) return;
    if (result case Ok(:final value)) {
      _live = {for (final b in value) b.address: b};
      _lastCategoryId = value.firstOrNull?.categoryId;
      ribbons.value = {
        for (final b in value)
          if (_categoryById[b.categoryId] case final category?)
            b.address: category.builtin,
      };
      notifyListeners();
    }
  }

  /// Bookmarks [ayah], or removes the bookmark it has.
  Future<void> toggle(QuranAddress ayah) async {
    final bookmarks = _bookmarks;
    if (bookmarks == null) return;
    final existing = _live[ayah];
    if (existing != null) {
      if (await bookmarks.delete(existing.id) is Ok) _removed = existing;
    } else {
      final category = _lastCategoryId ?? _memoriseId;
      if (category == null) return;
      _removed = null;
      await bookmarks.add(ayah, category);
    }
    if (!_disposed) notifyListeners();
  }

  /// Puts back the bookmark [toggle] removed last.
  Future<void> undo() async {
    final removed = _removed;
    final bookmarks = _bookmarks;
    if (removed == null || bookmarks == null) return;
    _removed = null;
    await bookmarks.restore(removed.id);
    if (!_disposed) notifyListeners();
  }

  /// The undo is only offered where the removal happened.
  void leave() {
    if (_removed == null) return;
    _removed = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _bookmarks?.removeListener(_changed);
    ribbons.dispose();
    super.dispose();
  }
}
