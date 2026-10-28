import 'package:holyquran/domain/models/mark_span.dart';
import 'package:holyquran/domain/models/word_span.dart';

/// A stretch of an ayah that a line never breaks inside, as half-open UTF-16
/// offsets into its pack text: a stored word with the marks that follow it
/// (`WQ-01`). The first unit also holds what comes before the first word, the
/// last what comes after the last one. [tokens] are the stored words and
/// marks inside it, in order; everything else in it is space.
final class BreakUnit {
  const BreakUnit(this.start, this.end, this.tokens);

  final int start;
  final int end;
  final List<(int, int)> tokens;
}

/// An ayah cut into [units] at the spaces before its stored words, the only
/// places a line may break. [gaps] holds the spaces between unit k and unit
/// k + 1, so units and gaps tile the text from 0 to [length]. Offsets only:
/// no character is read here.
final class AyahUnits {
  AyahUnits._(this.length, this.units, this.gaps);

  /// The units of a text of [length] code units with the stored [words] and
  /// [marks]. Two words with no space between them stay in one unit.
  factory AyahUnits.of(int length, List<WordSpan> words, List<MarkSpan> marks) {
    final tokens = [
      for (final word in words) (word.start, word.end, true),
      for (final mark in marks) (mark.start, mark.end, false),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    final units = <BreakUnit>[];
    final gaps = <(int, int)>[];
    var unitStart = 0;
    var unitTokens = <(int, int)>[];
    var hasWord = false;
    var lastEnd = 0;
    for (final (start, end, isWord) in tokens) {
      if (isWord && hasWord && lastEnd < start) {
        units.add(BreakUnit(unitStart, lastEnd, List.unmodifiable(unitTokens)));
        gaps.add((lastEnd, start));
        unitStart = start;
        unitTokens = [];
      }
      hasWord = hasWord || isWord;
      unitTokens.add((start, end));
      lastEnd = end;
    }
    units.add(BreakUnit(unitStart, length, List.unmodifiable(unitTokens)));
    return AyahUnits._(
      length,
      List.unmodifiable(units),
      List.unmodifiable(gaps),
    );
  }

  final int length;
  final List<BreakUnit> units;
  final List<(int, int)> gaps;

  /// The index of the unit holding [offset].
  int unitAt(int offset) {
    var low = 0;
    var high = units.length - 1;
    while (low < high) {
      final middle = (low + high + 1) ~/ 2;
      if (units[middle].start <= offset) {
        low = middle;
      } else {
        high = middle - 1;
      }
    }
    return low;
  }
}
