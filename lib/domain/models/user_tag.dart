/// A free tag shared by bookmarks and notes (`UD-02`). The name is the
/// user's text, kept as typed.
final class UserTag {
  const UserTag({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  final String id;
  final String name;
  final DateTime createdAt;

  @override
  bool operator ==(Object other) =>
      other is UserTag &&
      other.id == id &&
      other.name == name &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id, name, createdAt);

  @override
  String toString() => 'UserTag($id)';
}
