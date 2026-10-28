import 'package:holyquran/domain/models/quran_address.dart';

/// What a tap or long press in surah-mode text lands on (PRD §7.4, D-095).
/// Addresses and numbers only, never text.
sealed class GestureTarget {
  const GestureTarget();
}

/// A word of the text, by its word address.
final class WordTarget extends GestureTarget {
  const WordTarget(this.word);

  final QuranAddress word;

  @override
  bool operator ==(Object other) => other is WordTarget && other.word == word;

  @override
  int get hashCode => Object.hash(WordTarget, word);

  @override
  String toString() => 'WordTarget($word)';
}

/// A stored mark of an ayah (D-083): [mark] is its number in the ayah.
final class WaqfMarkTarget extends GestureTarget {
  const WaqfMarkTarget(this.ayah, this.mark);

  final QuranAddress ayah;
  final int mark;

  @override
  bool operator ==(Object other) =>
      other is WaqfMarkTarget && other.ayah == ayah && other.mark == mark;

  @override
  int get hashCode => Object.hash(WaqfMarkTarget, ayah, mark);

  @override
  String toString() => 'WaqfMarkTarget($ayah, $mark)';
}

/// The marker that ends an ayah.
final class MarkerTarget extends GestureTarget {
  const MarkerTarget(this.ayah);

  final QuranAddress ayah;

  @override
  bool operator ==(Object other) => other is MarkerTarget && other.ayah == ayah;

  @override
  int get hashCode => Object.hash(MarkerTarget, ayah);

  @override
  String toString() => 'MarkerTarget($ayah)';
}

/// Anything else: a gap, the margin, the basmala, a page mark.
final class MarginTarget extends GestureTarget {
  const MarginTarget();

  @override
  bool operator ==(Object other) => other is MarginTarget;

  @override
  int get hashCode => (MarginTarget).hashCode;

  @override
  String toString() => 'MarginTarget()';
}
