import 'generated_header.dart';
import 'generator_error.dart';
import 'icons_reader.dart';
import 'names.dart';
import 'project_icons_reader.dart';
import 'svg_shapes.dart';

/// Members every Dart enum has, which an enum value cannot be named.
const _enumMembers = {
  'index',
  'values',
  'hashCode',
  'runtimeType',
  'toString',
  'noSuchMethod',
};

/// The enum value for an icon: its `ICONS` key, or the key with the suffix
/// `Icon` when the key is a member every enum has (`index` → `indexIcon`).
String iconEnumValue(String iconName) =>
    _enumMembers.contains(iconName) ? '${iconName}Icon' : iconName;

/// The source of `icon_paths.g.dart`, before formatting.
String writeIcons(IconSet icons) {
  final values = [for (final icon in icons.icons) iconEnumValue(icon.name)];
  requireUnique(values, 'IconName');
  final filled = [
    for (final (i, icon) in icons.icons.indexed)
      if (icon.filled) values[i],
  ];
  if (filled.isEmpty) throw GeneratorError('No icon is filled.');

  final out =
      StringBuffer(
          generatedHeader([
            componentsSourcePath,
            typesSourcePath,
            '$projectIconsDirectory/*.svg',
          ]),
        )
        ..writeln("import 'package:flutter/painting.dart';")
        ..writeln()
        ..writeln(
          '/// The identity icons in the order of ICONS, then the project icons.',
        )
        ..writeln('enum IconName { ${values.join(', ')} }')
        ..writeln()
        ..writeln(
          '/// Filled icons are painted with a fill; all others with the',
        )
        ..writeln('/// identity stroke.')
        ..writeln('bool isIconFilled(IconName name) => switch (name) {')
        ..writeln('${filled.map((v) => 'IconName.$v').join(' || ')} => true,')
        ..writeln('_ => false,')
        ..writeln('};')
        ..writeln()
        ..writeln('/// The outline of [name] on the 24 by 24 icon grid.')
        ..writeln('Path buildIconPath(IconName name) => switch (name) {');
  for (final (i, icon) in icons.icons.indexed) {
    out.writeln('IconName.${values[i]} => ${_pathExpression(icon.ops)},');
  }
  out
    ..writeln('};')
    ..writeln()
    ..writeln('/// The open book of the mark on its 120 by 120 grid.')
    ..writeln('Path buildMarkBookPath() => ${_pathExpression(icons.bookOps)};');
  return out.toString();
}

String _pathExpression(List<PathOp> ops) =>
    'Path()${ops.map((op) => op.toDart()).join()}';
