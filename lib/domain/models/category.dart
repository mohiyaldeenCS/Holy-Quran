/// The categories the identity draws (its tag component). Further ones and
/// user-made categories wait for the owner's answer to O-14.
enum BuiltinCategory {
  memorise('memorise'),
  review('review'),
  study('study'),
  important('important');

  const BuiltinCategory(this.key);

  /// The key stored and synced for this category; it never changes, so a
  /// renamed value still finds its rows.
  final String key;

  /// The category stored as [key], or null when there is none, as for a key
  /// a later version made.
  static BuiltinCategory? fromKey(String? key) {
    for (final category in values) {
      if (category.key == key) return category;
    }
    return null;
  }
}

/// A category of bookmarks and notes (`UD-01`, `UD-04`).
final class Category {
  const Category({required this.id, required this.builtin});

  final String id;
  final BuiltinCategory builtin;

  @override
  bool operator ==(Object other) =>
      other is Category && other.id == id && other.builtin == builtin;

  @override
  int get hashCode => Object.hash(id, builtin);

  @override
  String toString() => 'Category($id, ${builtin.key})';
}
