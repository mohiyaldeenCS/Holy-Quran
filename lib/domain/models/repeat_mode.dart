/// What a repeat count applies to (`AU-09`).
enum RepeatUnit { ayah, range, page, surah }

/// Each [unit] is heard [count] times, exactly, or without end when [count]
/// is null.
final class RepeatMode {
  RepeatMode(this.unit, int count)
    : count = RangeError.checkValueInInterval(
        count,
        minCount,
        maxCount,
        'count',
      );

  const RepeatMode.unlimited(this.unit) : count = null;

  const RepeatMode._once() : unit = RepeatUnit.range, count = 1;

  static const minCount = 1;
  static const maxCount = 99;

  /// Everything heard once.
  static const once = RepeatMode._once();

  final RepeatUnit unit;
  final int? count;

  bool get isUnlimited => count == null;

  @override
  bool operator ==(Object other) =>
      other is RepeatMode && other.unit == unit && other.count == count;

  @override
  int get hashCode => Object.hash(unit, count);

  @override
  String toString() => 'RepeatMode(${unit.name}, ${count ?? 'unlimited'})';
}
