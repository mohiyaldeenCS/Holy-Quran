import 'quran_address.dart';

enum Division { juz, hizb, rub, page }

/// The divisions and sajdas of a reference edition, as ayah addresses read
/// from the pack.
final class EditionMap {
  EditionMap({
    required this.edition,
    required Map<Division, List<QuranAddress>> starts,
    required Set<QuranAddress> sajdas,
  }) : _starts = Map.unmodifiable({
         for (final MapEntry(:key, :value) in starts.entries)
           key: List<QuranAddress>.unmodifiable(value),
       }),
       sajdas = Set.unmodifiable(sajdas) {
    final riwayat = {
      for (final list in _starts.values)
        for (final address in list) address.riwaya,
      for (final address in this.sajdas) address.riwaya,
    };
    if (riwayat.length > 1) {
      throw ArgumentError('An edition map mixes riwayat: $riwayat');
    }
    for (final MapEntry(key: division, value: list) in _starts.entries) {
      for (final (index, address) in list.indexed) {
        final name = '${division.name} ${index + 1}';
        if (address.isWord) {
          throw ArgumentError.value(address, name, 'must be an ayah address');
        }
        if (index > 0 && list[index - 1].compareTo(address) >= 0) {
          throw ArgumentError.value(
            address,
            name,
            'must follow ${list[index - 1]}',
          );
        }
      }
    }
    for (final address in this.sajdas) {
      if (address.isWord) {
        throw ArgumentError.value(address, 'sajda', 'must be an ayah address');
      }
    }
  }

  final String edition;
  final Map<Division, List<QuranAddress>> _starts;
  final Set<QuranAddress> sajdas;

  List<QuranAddress> _startsOf(Division division) =>
      _starts[division] ?? const [];

  int count(Division division) => _startsOf(division).length;

  /// The number of the [division] unit holding the ayah of [address]. Throws
  /// an [ArgumentError] when the ayah comes before the first unit.
  int numberAt(Division division, QuranAddress address) {
    final starts = _startsOf(division);
    final ayah = address.ayahAddress;
    var low = 0;
    var high = starts.length;
    while (low < high) {
      final middle = (low + high) ~/ 2;
      if (starts[middle].compareTo(ayah) <= 0) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    if (low == 0) {
      throw ArgumentError.value(
        address,
        'address',
        'is in no ${division.name}',
      );
    }
    return low;
  }

  /// The first ayah of unit [number], counted from 1.
  QuranAddress startOf(Division division, int number) {
    final starts = _startsOf(division);
    if (number < 1 || number > starts.length) {
      throw RangeError.range(number, 1, starts.length, 'number');
    }
    return starts[number - 1];
  }

  /// Whether the ayah of [address] carries a sajda.
  bool isSajda(QuranAddress address) => sajdas.contains(address.ayahAddress);
}
