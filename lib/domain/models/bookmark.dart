import 'quran_address.dart';

/// How long a deleted bookmark, note or tag can be restored (`UD-07`). It is
/// longer than the undo snackbar is shown: that snackbar does not persist
/// and its duration lies well inside this window, so its undo button never
/// outlives the undo.
const undoWindow = Duration(seconds: 30);

/// What bookmarks and notes share: an ayah, a category, tags and a time of
/// creation (`UD-01`, `UD-02`, `UD-04`).
abstract class AyahAnnotation {
  const AyahAnnotation();

  String get id;
  QuranAddress get address;
  String? get categoryId;

  /// The ids of its live tags.
  Set<String> get tagIds;
  DateTime get createdAt;

  /// The user's own text that a search looks in besides tag names.
  Iterable<String> get searchedText => const [];

  /// Whether this is in [categoryId] and tagged [tagId] when they are given,
  /// and [query] is empty or inside its searched text or the name of one of
  /// its tags in [tagNames] (`UD-03`, `SR-08`). The strings are compared as
  /// the user typed them.
  bool matches({
    String? categoryId,
    String? tagId,
    String query = '',
    Map<String, String> tagNames = const {},
  }) =>
      (categoryId == null || this.categoryId == categoryId) &&
      (tagId == null || tagIds.contains(tagId)) &&
      (query.isEmpty ||
          searchedText.any((text) => text.contains(query)) ||
          tagIds.any((id) => tagNames[id]?.contains(query) ?? false));
}

/// The order of a list of bookmarks or notes (`UD-03`).
enum ListOrder {
  newest,

  /// By riwaya, then surah and ayah; older first on the same ayah.
  mushaf;

  int compare(AyahAnnotation a, AyahAnnotation b) {
    final byOrder = switch (this) {
      newest => b.createdAt.compareTo(a.createdAt),
      mushaf => _byAddress(a.address, b.address),
    };
    if (byOrder != 0) return byOrder;
    final byTime = a.createdAt.compareTo(b.createdAt);
    return byTime != 0 ? byTime : a.id.compareTo(b.id);
  }

  static int _byAddress(QuranAddress a, QuranAddress b) {
    final byRiwaya = a.riwaya.compareTo(b.riwaya);
    return byRiwaya != 0 ? byRiwaya : a.compareTo(b);
  }
}

/// A whole ayah kept by the user in exactly one category (`UD-01`).
final class Bookmark extends AyahAnnotation {
  Bookmark({
    required this.id,
    required this.address,
    required this.categoryId,
    required Set<String> tagIds,
    required this.createdAt,
    required this.updatedAt,
  }) : tagIds = Set.unmodifiable(tagIds) {
    if (address.isWord) {
      throw ArgumentError.value(address, 'address', 'is a word address');
    }
  }

  @override
  final String id;
  @override
  final QuranAddress address;
  @override
  final String categoryId;
  @override
  final Set<String> tagIds;
  @override
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  bool operator ==(Object other) =>
      other is Bookmark &&
      other.id == id &&
      other.address == address &&
      other.categoryId == categoryId &&
      sameIds(other.tagIds, tagIds) &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
    id,
    address,
    categoryId,
    Object.hashAllUnordered(tagIds),
    createdAt,
    updatedAt,
  );

  @override
  String toString() => 'Bookmark($id, $address)';
}

/// Whether [a] and [b] hold the same ids.
bool sameIds(Set<String> a, Set<String> b) =>
    a.length == b.length && a.containsAll(b);

/// No live bookmark, note or tag has [id].
final class ItemNotFound implements Exception {
  const ItemNotFound(this.id);

  final String id;

  @override
  String toString() => 'ItemNotFound($id)';
}

/// [id] was deleted longer ago than [undoWindow] and stays deleted.
final class UndoExpired implements Exception {
  const UndoExpired(this.id);

  final String id;

  @override
  String toString() => 'UndoExpired($id)';
}

/// [address] has a live bookmark already, so another cannot be restored
/// there.
final class AyahAlreadyBookmarked implements Exception {
  const AyahAlreadyBookmarked(this.address);

  final QuranAddress address;

  @override
  String toString() => 'AyahAlreadyBookmarked($address)';
}

/// Another live tag is named exactly [name].
final class TagNameTaken implements Exception {
  const TagNameTaken(this.name);

  final String name;

  @override
  String toString() => 'TagNameTaken($name)';
}
