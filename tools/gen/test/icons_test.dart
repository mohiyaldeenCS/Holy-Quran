import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../lib/generator_error.dart';
import '../lib/icons_reader.dart';
import '../lib/icons_writer.dart';
import '../lib/svg_shapes.dart';
import 'synthetic_sources.dart';

Matcher throwsGeneratorError(String fragment) => throwsA(
  isA<GeneratorError>().having((e) => e.message, 'message', contains(fragment)),
);

String _dart(List<PathOp> ops) => ops.map((op) => op.toDart()).join();

void main() {
  group('the reference components', () {
    final icons = readIcons(
      components: File(componentsSourcePath).readAsStringSync(),
      types: File(typesSourcePath).readAsStringSync(),
    );

    test('give the 26 icons in ICONS order', () {
      expect(icons.icons.map((i) => i.name), [
        'home',
        'mushaf',
        'listen',
        'study',
        'search',
        'bookmark',
        'download',
        'night',
        'settings',
        'repeat',
        'index',
        'khatma',
        'next',
        'previous',
        'more',
        'alert',
        'check',
        'close',
        'play',
        'pause',
        'mic',
        'eye',
        'sort',
        'minus',
        'plus',
        'context',
      ]);
    });

    test('mark only play and pause as filled', () {
      expect(
        [
          for (final i in icons.icons)
            if (i.filled) i.name,
        ],
        ['play', 'pause'],
      );
    });

    test('give the book of the mark on the 120 grid', () {
      expect(_dart(icons.bookOps), startsWith('..moveTo(58, 52)'));
      expect(icons.bookOps.whereType<Close>(), hasLength(2));
    });
  });

  group('SVG shapes', () {
    test('path, rect with rx and circle become Path calls', () {
      expect(
        _dart(
          shapesToPathOps(
            '<path d="M4 4h2v2z"/><rect x="1" y="2" width="6" height="4" '
                'rx="1.5"/> <circle cx="12" cy="12" r="1.2"/>',
            'test',
          ),
        ),
        '..moveTo(4, 4)..lineTo(6, 4)..lineTo(6, 6)..close()'
        '..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(1, 2, 6, 4), '
        'Radius.circular(1.5)))'
        '..addOval(Rect.fromCircle(center: Offset(12, 12), radius: 1.2))',
      );
    });

    test('arcs become cubics ending on the arc end point', () {
      final ops = pathDataToOps('M5 11V9a3 3 0 0 1 3-3', 'test');
      expect(ops.last, isA<CubicTo>());
      expect(ops.last.toDart(), endsWith(', 8, 6)'));
    });

    test('an unknown element stops the generator', () {
      expect(
        () => shapesToPathOps('<line x1="0" y1="0" x2="1" y2="1"/>', 'test'),
        throwsGeneratorError('unknown SVG element <line>'),
      );
    });

    test('an attribute that changes the drawing stops the generator', () {
      expect(
        () => shapesToPathOps('<path d="M0 0h1" transform="scale(2)"/>', 't'),
        throwsGeneratorError('"transform"'),
      );
      expect(
        () => shapesToPathOps('<rect x="0" y="0" width="4" height="4"/>', 't'),
        throwsGeneratorError('no "rx"'),
      );
    });

    test('markup that is not self-closing elements stops the generator', () {
      expect(
        () => shapesToPathOps('<g><path d="M0 0h1"/></g>', 't'),
        throwsGeneratorError('cannot read'),
      );
    });

    test('invalid path data stops the generator', () {
      expect(
        () => pathDataToOps('M0 0 Q', 't'),
        throwsGeneratorError('invalid'),
      );
    });
  });

  group('readIcons', () {
    test('reads synthetic sources in order', () {
      final icons = readIcons(
        components: syntheticComponents(),
        types: syntheticTypes(),
      );
      expect(icons.icons.map((i) => (i.name, i.filled)), [
        ('square', true),
        ('ring', false),
        ('index', false),
      ]);
    });

    test('an IconName type that differs from ICONS stops the generator', () {
      expect(
        () => readIcons(
          components: syntheticComponents(),
          types: syntheticTypes(names: "'square' | 'ring'"),
        ),
        throwsGeneratorError('differs'),
      );
    });

    test('a FILLED name missing from ICONS stops the generator', () {
      expect(
        () => readIcons(
          components: syntheticComponents(filled: 'square: 1, star: 1'),
          types: syntheticTypes(),
        ),
        throwsGeneratorError('"star"'),
      );
    });

    test('a line in ICONS that is not an entry stops the generator', () {
      expect(
        () => readIcons(
          components: syntheticComponents(icons: '  ...MORE_ICONS,\n'),
          types: syntheticTypes(),
        ),
        throwsGeneratorError('not an ICONS entry'),
      );
    });
  });

  group('writeIcons', () {
    final output = writeIcons(
      readIcons(components: syntheticComponents(), types: syntheticTypes()),
    );

    test('names an icon called after an Enum member with the suffix Icon', () {
      expect(iconEnumValue('index'), 'indexIcon');
      expect(iconEnumValue('home'), 'home');
      expect(output, contains('enum IconName { square, ring, indexIcon }'));
    });

    test('writes the filled set, the icon paths and the book', () {
      expect(output, contains('IconName.square => true,'));
      expect(output, contains('Path buildIconPath(IconName name)'));
      expect(output, contains('Path buildMarkBookPath() => Path()'));
    });
  });
}
