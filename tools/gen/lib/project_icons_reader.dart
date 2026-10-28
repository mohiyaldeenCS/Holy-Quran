import 'dart:io';

import 'generator_error.dart';
import 'icons_reader.dart';
import 'svg_shapes.dart';

const projectIconsDirectory = 'tools/gen/project_icons';

/// The owner-approved icons (D-051, D-128), appended to the identity's after
/// its last one, in this order. A file in the folder that is not listed here
/// is not approved and stops the generator.
const projectIconNames = [
  'copy',
  'delete',
  'info',
  'nextSurah',
  'note',
  'previousSurah',
  'share',
  'stop',
];

// What `Icon` in the reference components puts around an icon's shapes.
const _open =
    '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" '
    'viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" '
    'stroke-linecap="round" stroke-linejoin="round">';
const _close = '</svg>\n';

/// The project icons under [root], all line icons, in [projectIconNames] order.
List<IconShape> readProjectIcons(String root) {
  final directory = Directory('$root/$projectIconsDirectory');
  if (!directory.existsSync()) {
    throw GeneratorError('Missing source $projectIconsDirectory.');
  }
  final found = {
    for (final entity in directory.listSync())
      if (entity is File && entity.path.endsWith('.svg'))
        entity.uri.pathSegments.last.replaceFirst(RegExp(r'\.svg$'), ''),
  };
  final unapproved = found.difference(projectIconNames.toSet());
  if (unapproved.isNotEmpty) {
    throw GeneratorError(
      '$projectIconsDirectory holds icons that are not approved: '
      '${(unapproved.toList()..sort()).join(', ')}.',
    );
  }
  return [
    for (final name in projectIconNames)
      _readIcon(File('${directory.path}/$name.svg'), name),
  ];
}

IconShape _readIcon(File file, String name) {
  if (!file.existsSync()) {
    throw GeneratorError('Missing source $projectIconsDirectory/$name.svg.');
  }
  final text = file.readAsStringSync();
  if (!text.startsWith(_open) || !text.endsWith(_close)) {
    throw GeneratorError(
      '$projectIconsDirectory/$name.svg is not framed as the Icon component '
      'draws a line icon.',
    );
  }
  final markup = text.substring(_open.length, text.length - _close.length);
  return IconShape(
    name,
    shapesToPathOps(markup, 'project icon "$name"'),
    filled: false,
  );
}
