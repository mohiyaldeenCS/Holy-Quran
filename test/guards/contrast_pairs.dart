import 'allow_list.dart';

enum ContrastUse { text, nonText }

/// [over] is the opaque colour a translucent [bg] is composited onto.
typedef ContrastPair = ({String fg, String bg, String? over, ContrastUse use});

String contrastName(ContrastPair pair) =>
    '${pair.fg} on ${pair.bg}${pair.over == null ? '' : ' over ${pair.over}'}';

final _pair = RegExp(
  r'^(card )?(text|non-text): ([a-z0-9@-]+) on ([a-z0-9@-]+)'
  r'(?: over ([a-z0-9@-]+))?$',
);
final _ratioKey = RegExp('^(exception|pinned):');
final _ratio = RegExp(r'^(exception|pinned): ([a-z]+) (\d+\.\d\d)$');

/// The contrast entries of a folder (test/guards/allow/README.md): the
/// [pairs] measured in every app theme, the [cardPairs] of fixed card
/// designs, and the [exceptions] and [pinned] ratios keyed `theme: pair`.
final class ContrastEntries {
  ContrastEntries._(this.pairs, this.cardPairs, this.exceptions, this.pinned);

  /// Loads [folder]; throws [AllowListError] on a malformed entry or a pair
  /// listed twice.
  factory ContrastEntries.load(String folder) {
    final pairs = <ContrastPair>[];
    final cardPairs = <ContrastPair>[];
    final exceptions = <String, double>{};
    final pinned = <String, double>{};
    final problems = <String>[];
    final seen = <String, String>{};
    for (final entry in readAllowEntries(folder)) {
      final match = _pair.firstMatch(entry.target);
      if (match == null) {
        problems.add('${entry.file}: line 1 is not "[card ]<use>: a on b"');
        continue;
      }
      final card = match[1] != null;
      final pair = (
        fg: match[3]!,
        bg: match[4]!,
        over: match[5],
        use: match[2] == 'text' ? ContrastUse.text : ContrastUse.nonText,
      );
      final name = '${card ? 'card ' : ''}${contrastName(pair)}';
      final first = seen.putIfAbsent(name, () => entry.file);
      if (first != entry.file) {
        problems.add('${entry.file}: $name also listed in $first');
        continue;
      }
      final lines = entry.rest;
      for (final (index, line) in lines.indexed) {
        final ratio = _ratio.firstMatch(line);
        if (ratio != null && (ratio[2] == 'card') != card) {
          problems.add(
            '${entry.file}: ${ratio[2]} is not the theme of the pair',
          );
        } else if (ratio != null) {
          final key = '${ratio[2]}: ${contrastName(pair)}';
          if (exceptions.containsKey(key) || pinned.containsKey(key)) {
            problems.add('${entry.file}: ${ratio[2]} given twice');
          }
          (ratio[1] == 'exception' ? exceptions : pinned)[key] = double.parse(
            ratio[3]!,
          );
        } else if (index != lines.length - 1 || line.startsWith(_ratioKey)) {
          problems.add('${entry.file}: "$line" is not a ratio line');
        }
      }
      (card ? cardPairs : pairs).add(pair);
    }
    if (problems.isNotEmpty) throw AllowListError(folder, problems);
    return ContrastEntries._(pairs, cardPairs, exceptions, pinned);
  }

  final List<ContrastPair> pairs;
  final List<ContrastPair> cardPairs;
  final Map<String, double> exceptions;
  final Map<String, double> pinned;
}
