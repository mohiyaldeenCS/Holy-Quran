import 'bookmark.dart';
import 'quran_address.dart';

/// The user's text on an ayah, in at most one category (`UD-04`). An ayah
/// may have several.
final class Note extends AyahAnnotation {
  Note({
    required this.id,
    required this.address,
    required this.body,
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
  final String body;
  @override
  final String? categoryId;
  @override
  final Set<String> tagIds;
  @override
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  Iterable<String> get searchedText => [body];

  @override
  bool operator ==(Object other) =>
      other is Note &&
      other.id == id &&
      other.address == address &&
      other.body == body &&
      other.categoryId == categoryId &&
      sameIds(other.tagIds, tagIds) &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
    id,
    address,
    body,
    categoryId,
    Object.hashAllUnordered(tagIds),
    createdAt,
    updatedAt,
  );

  @override
  String toString() => 'Note($id, $address)';
}
