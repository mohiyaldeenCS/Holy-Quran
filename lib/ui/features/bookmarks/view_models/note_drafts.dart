import 'package:holyquran/domain/models/quran_address.dart';

/// A note not yet saved: its text, category and tags.
final class NoteDraft {
  const NoteDraft({
    required this.body,
    required this.categoryId,
    required this.tagIds,
  });

  final String body;
  final String? categoryId;
  final Set<String> tagIds;
}

/// The unsaved notes of this session, one per ayah and per note being edited
/// (a new note has no id). They live in memory only and are never written to
/// the database; a note is stored by «حفظ» alone. They are lost when the app
/// closes. The app has one, [session].
final class NoteDrafts {
  NoteDrafts();

  /// The drafts of the running app, for a sheet that is given no others.
  static final NoteDrafts session = NoteDrafts();

  final _drafts = <(QuranAddress, String?), NoteDraft>{};

  NoteDraft? of(QuranAddress ayah, String? noteId) => _drafts[(ayah, noteId)];

  void keep(QuranAddress ayah, String? noteId, NoteDraft draft) =>
      _drafts[(ayah, noteId)] = draft;

  void drop(QuranAddress ayah, String? noteId) =>
      _drafts.remove((ayah, noteId));

  void clear() => _drafts.clear();
}
