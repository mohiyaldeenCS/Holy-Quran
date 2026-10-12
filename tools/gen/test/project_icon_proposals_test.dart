import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import '../lib/icons_reader.dart';
import '../lib/svg_shapes.dart';

const _proposalsPath = 'docs/plans/icons';

// The eight drawings of D-051 and D-059, as the owner reviews them.
const _proposalNames = {
  'copy',
  'share',
  'info',
  'note',
  'delete',
  'stop',
  'nextSurah',
  'previousSurah',
};

// The attributes `Icon` in the reference components gives a line icon, so
// each file renders as the component would draw it. D-051 approved line icons:
// none of the eight is filled.
const _open =
    '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" '
    'viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" '
    'stroke-linecap="round" stroke-linejoin="round">';
const _close = '</svg>\n';

final _pathData = RegExp(r'<path d="([^"]*)"');
final _command = RegExp(r'[A-Za-z]');

final class _Proposal {
  _Proposal(File file)
    : name = file.uri.pathSegments.last.replaceFirst('.svg', ''),
      text = file.readAsStringSync();

  final String name;
  final String text;

  bool get opensLikeIcon => text.startsWith(_open) && text.endsWith(_close);

  String get markup {
    if (!opensLikeIcon) throw StateError('$name.svg is not framed like Icon.');
    return text.substring(_open.length, text.length - _close.length);
  }

  late final List<PathOp> ops = shapesToPathOps(markup, 'proposal "$name"');

  Set<String> get commands => _commandsIn(markup);
}

Set<String> _commandsIn(String markup) => {
  for (final match in _pathData.allMatches(markup))
    ..._command.allMatches(match.group(1)!).map((m) => m.group(0)!),
};

Rectangle<double> _bounds(List<PathOp> ops) {
  final points = <Point<double>>[];
  for (final op in ops) {
    switch (op) {
      case MoveTo(:final x, :final y) || LineTo(:final x, :final y):
        points.add(Point(x, y));
      case CubicTo():
        points
          ..add(Point(op.x1, op.y1))
          ..add(Point(op.x2, op.y2))
          ..add(Point(op.x3, op.y3));
      case AddRRect(:final x, :final y, :final width, :final height):
        points
          ..add(Point(x, y))
          ..add(Point(x + width, y + height));
      case AddOval(:final cx, :final cy, :final r):
        points
          ..add(Point(cx - r, cy - r))
          ..add(Point(cx + r, cy + r));
      case Close():
        break;
    }
  }
  final xs = points.map((p) => p.x);
  final ys = points.map((p) => p.y);
  return Rectangle.fromPoints(
    Point(xs.reduce(min), ys.reduce(min)),
    Point(xs.reduce(max), ys.reduce(max)),
  );
}

void main() {
  final components = File(componentsSourcePath).readAsStringSync();
  final identity = readIcons(
    components: components,
    types: File(typesSourcePath).readAsStringSync(),
  );
  final iconsBlock = components.substring(
    components.indexOf('const ICONS = {'),
    components.indexOf('\n};', components.indexOf('const ICONS = {')),
  );
  final identityMarkup = RegExp(
    r"^\s+[a-z][a-zA-Z0-9]*: '([^']*)',$",
    multiLine: true,
  ).allMatches(iconsBlock);
  final identityCommands = {
    for (final match in identityMarkup) ..._commandsIn(match.group(1)!),
  };
  final identityBox = identity.icons
      .map((icon) => _bounds(icon.ops))
      .reduce((a, b) => a.boundingBox(b));

  final proposals = [
    for (final entity in Directory(_proposalsPath).listSync())
      if (entity is File && entity.path.endsWith('.svg')) _Proposal(entity),
  ];

  test('there is one file for each of the eight drawings', () {
    expect(proposals.map((p) => p.name).toSet(), _proposalNames);
    expect(proposals, hasLength(_proposalNames.length));
  });

  test('no proposal takes the name of an identity icon', () {
    final taken = identity.icons.map((icon) => icon.name).toSet();
    expect(proposals.where((p) => taken.contains(p.name)), isEmpty);
  });

  for (final proposal in proposals) {
    group(proposal.name, () {
      test('opens and closes as the Icon component draws it', () {
        expect(proposal.opensLikeIcon, isTrue);
      });

      test('parses with the generator\'s own SVG reader', () {
        expect(proposal.ops, isNotEmpty);
      });

      test('uses only path commands the identity\'s icons use', () {
        expect(proposal.commands.difference(identityCommands), isEmpty);
      });

      test('stays inside the area the identity\'s icons cover', () {
        final box = _bounds(proposal.ops);
        expect(
          identityBox.containsRectangle(box),
          isTrue,
          reason: '$box is not inside $identityBox',
        );
      });
    });
  }

  test('the preview shows every proposal as its file draws it', () {
    final preview = File('$_proposalsPath/preview.html').readAsStringSync();
    expect(identityMarkup, hasLength(identity.icons.length));
    for (final proposal in proposals) {
      expect(preview, contains(proposal.markup), reason: proposal.name);
    }
    for (final match in identityMarkup) {
      expect(preview, contains(match.group(1)!));
    }
  });
}
