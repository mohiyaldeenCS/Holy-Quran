import 'quran_address.dart';

/// Where listening stopped on this device (`AU-16`, D-106).
final class ListeningPosition {
  /// Throws an [ArgumentError] when [address] is a word address or [offset]
  /// is negative.
  ListeningPosition({
    required this.address,
    required this.recitationId,
    required this.offset,
  }) {
    if (address.isWord) {
      throw ArgumentError.value(address, 'address', 'is a word address');
    }
    if (offset.isNegative) {
      throw ArgumentError.value(offset, 'offset', 'is negative');
    }
  }

  final QuranAddress address;
  final String recitationId;

  /// The playback time the player stopped at; the player decides what it is
  /// measured from.
  final Duration offset;

  @override
  bool operator ==(Object other) =>
      other is ListeningPosition &&
      other.address == address &&
      other.recitationId == recitationId &&
      other.offset == offset;

  @override
  int get hashCode => Object.hash(address, recitationId, offset);

  @override
  String toString() => 'ListeningPosition($address, $recitationId, $offset)';
}
