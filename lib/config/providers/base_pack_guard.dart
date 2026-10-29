/// What a reader of the verified base pack needs to stay honest about it: to
/// stop while the pack is not serving, and to disable it when a read finds it
/// broken. The Quran area owns the pack's integrity and provides this once the
/// pack verified.
final class BasePackGuard {
  const BasePackGuard({required this.serving, required this.failed});

  /// Whether the pack is still verified and in use.
  final bool Function() serving;

  /// Disables the pack for [error], once, and forgets its remembered check.
  final void Function(Exception error) failed;
}
