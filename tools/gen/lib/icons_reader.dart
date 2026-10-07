import 'generator_error.dart';
import 'svg_shapes.dart';

const componentsSourcePath = 'design/design-system/components/src/index.jsx';
const typesSourcePath = 'design/design-system/components/index.d.ts';

/// The icon set and the book of the mark, read from the reference
/// components. Only `ICONS`, `FILLED` and `BOOK` are read.
final class IconSet {
  const IconSet(this.icons, this.bookOps);

  /// In `ICONS` order.
  final List<IconShape> icons;

  /// The open book of `Mark`, on its 120 grid.
  final List<PathOp> bookOps;
}

final class IconShape {
  const IconShape(this.name, this.ops, {required this.filled});

  final String name;
  final List<PathOp> ops;
  final bool filled;
}

final _iconsStart = RegExp(r'^const ICONS = \{$');
final _iconsEnd = RegExp(r'^\};$');
final _iconLine = RegExp(r"^\s+([a-z][a-zA-Z0-9]*): '([^'\\]*)',$");
final _filledLine = RegExp(r'^const FILLED = \{ (.*) \};$');
final _filledEntry = RegExp(r'^([a-z][a-zA-Z0-9]*): 1$');
final _bookLine = RegExp(r"^const BOOK = '([^'\\]*)';$");
final _iconNameType = RegExp(
  r'^export type IconName = (.+);$',
  multiLine: true,
);
final _quotedName = RegExp(r"^'([a-z][a-zA-Z0-9]*)'$");

IconSet readIcons({required String components, required String types}) {
  final lines = components.split(RegExp(r'\r?\n'));
  final markup = _readIconMarkup(lines);
  final filled = _readFilled(lines, markup.keys.toSet());
  _checkIconNameType(types, markup.keys.toList());
  final book = _single(lines, _bookLine, 'BOOK');
  return IconSet([
    for (final MapEntry(key: name, value: svg) in markup.entries)
      IconShape(
        name,
        shapesToPathOps(svg, 'icon "$name"'),
        filled: filled.contains(name),
      ),
  ], pathDataToOps(book, 'BOOK'));
}

Map<String, String> _readIconMarkup(List<String> lines) {
  final starts = [
    for (final (i, line) in lines.indexed)
      if (_iconsStart.hasMatch(line)) i,
  ];
  if (starts.length != 1) {
    throw GeneratorError(
      '$componentsSourcePath has ${starts.length} "const ICONS = {" lines, not 1.',
    );
  }
  final markup = <String, String>{};
  for (var i = starts.single + 1; i < lines.length; i++) {
    final line = lines[i];
    if (_iconsEnd.hasMatch(line)) {
      if (markup.isEmpty) throw GeneratorError('ICONS is empty.');
      return markup;
    }
    final match = _iconLine.firstMatch(line);
    if (match == null) {
      throw GeneratorError(
        '$componentsSourcePath line ${i + 1} is not an ICONS entry: "$line".',
      );
    }
    if (markup.containsKey(match.group(1))) {
      throw GeneratorError('ICONS has "${match.group(1)}" twice.');
    }
    markup[match.group(1)!] = match.group(2)!;
  }
  throw GeneratorError('ICONS in $componentsSourcePath has no closing "};".');
}

Set<String> _readFilled(List<String> lines, Set<String> iconNames) {
  final body = _single(lines, _filledLine, 'FILLED');
  final names = <String>{};
  for (final entry in body.split(',').map((e) => e.trim())) {
    final match = _filledEntry.firstMatch(entry);
    if (match == null) {
      throw GeneratorError(
        'FILLED has an entry "$entry" that is not "name: 1".',
      );
    }
    final name = match.group(1)!;
    if (!iconNames.contains(name)) {
      throw GeneratorError('FILLED names "$name", which is not in ICONS.');
    }
    names.add(name);
  }
  return names;
}

void _checkIconNameType(String types, List<String> iconNames) {
  final matches = _iconNameType.allMatches(types).toList();
  if (matches.length != 1) {
    throw GeneratorError('$typesSourcePath does not declare IconName once.');
  }
  final declared = [
    for (final part in matches.single.group(1)!.split('|'))
      _quotedName.firstMatch(part.trim())?.group(1) ??
          (throw GeneratorError('IconName has an entry "$part".')),
  ];
  final same =
      declared.length == iconNames.length &&
      declared.toSet().containsAll(iconNames);
  if (!same) {
    throw GeneratorError(
      'IconName in $typesSourcePath (${declared.join(', ')}) differs from '
      'the keys of ICONS (${iconNames.join(', ')}).',
    );
  }
}

String _single(List<String> lines, RegExp pattern, String what) {
  final found = [
    for (final line in lines)
      if (pattern.firstMatch(line) case final match?) match.group(1)!,
  ];
  if (found.length != 1) {
    throw GeneratorError(
      '$componentsSourcePath declares $what ${found.length} times, not once.',
    );
  }
  return found.single;
}
