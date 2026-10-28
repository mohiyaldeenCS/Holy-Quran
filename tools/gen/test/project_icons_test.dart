import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';

import '../lib/generator.dart';
import '../lib/generator_error.dart';
import '../lib/icons_reader.dart';
import '../lib/project_icons_reader.dart';
import 'synthetic_sources.dart';

Matcher throwsGeneratorError(String fragment) => throwsA(
  isA<GeneratorError>().having((e) => e.message, 'message', contains(fragment)),
);

Directory _root({void Function(Directory root)? change}) {
  final root = Directory.systemTemp.createTempSync('project_icons_test_');
  addTearDown(() => root.deleteSync(recursive: true));
  Directory('${root.path}/$projectIconsDirectory').createSync(recursive: true);
  for (final name in projectIconNames) {
    File(
      '${root.path}/$projectIconsDirectory/$name.svg',
    ).writeAsStringSync(syntheticProjectIcon());
  }
  change?.call(root);
  return root;
}

void main() {
  const approvedDrawings = 'docs/plans/icons';

  group('the committed project icons', () {
    test('are byte for byte the approved drawings', () {
      for (final name in projectIconNames) {
        final approved = File('$approvedDrawings/$name.svg').readAsBytesSync();
        final copy = File('$projectIconsDirectory/$name.svg').readAsBytesSync();
        expect(sha256.convert(copy), sha256.convert(approved), reason: name);
      }
    });

    test('parse, and are line icons', () {
      final icons = readProjectIcons(Directory.current.path);
      expect(icons.map((i) => i.name), projectIconNames);
      expect(icons.every((i) => !i.filled && i.ops.isNotEmpty), isTrue);
    });

    test('come after the identity\'s 26 in IconName, in the fixed order', () {
      final identity = readIcons(
        components: File(componentsSourcePath).readAsStringSync(),
        types: File(typesSourcePath).readAsStringSync(),
      );
      expect(identity.icons, hasLength(26));
      final names = IconName.values.map((v) => v.name).toList();
      expect(
        names.take(26),
        identity.icons.map((i) => i.name == 'index' ? 'indexIcon' : i.name),
      );
      expect(names.skip(26), projectIconNames);
    });

    test('are generated into the committed file', () async {
      final code = await runGenerator(
        ['--check'],
        root: Directory.current.path,
        out: StringBuffer(),
        err: StringBuffer(),
      );
      expect(code, Exit.ok);
    });

    test('build inside the 24 grid and are not filled', () {
      for (final name in IconName.values.skip(26)) {
        final bounds = buildIconPath(name).getBounds();
        expect(bounds.isEmpty, isFalse, reason: name.name);
        expect(bounds.left >= 0 && bounds.top >= 0, isTrue);
        expect(bounds.right <= 24 && bounds.bottom <= 24, isTrue);
        expect(isIconFilled(name), isFalse, reason: name.name);
      }
    });
  });

  group('readProjectIcons', () {
    test('reads the files in the fixed order', () {
      final icons = readProjectIcons(_root().path);
      expect(icons.map((i) => i.name), projectIconNames);
    });

    test('a missing file stops the generator', () {
      final root = _root(
        change: (r) =>
            File('${r.path}/$projectIconsDirectory/stop.svg').deleteSync(),
      );
      expect(
        () => readProjectIcons(root.path),
        throwsGeneratorError('stop.svg'),
      );
    });

    test('a file that is not approved stops the generator', () {
      final root = _root(
        change: (r) => File(
          '${r.path}/$projectIconsDirectory/extra.svg',
        ).writeAsStringSync(syntheticProjectIcon()),
      );
      expect(() => readProjectIcons(root.path), throwsGeneratorError('extra'));
    });

    test('a file with another frame stops the generator', () {
      final root = _root(
        change: (r) => File(
          '${r.path}/$projectIconsDirectory/copy.svg',
        ).writeAsStringSync('<svg><path d="M0 0h1v1z"/></svg>\n'),
      );
      expect(() => readProjectIcons(root.path), throwsGeneratorError('framed'));
    });

    test('an element the generator cannot read stops it', () {
      final root = _root(
        change: (r) => File(
          '${r.path}/$projectIconsDirectory/copy.svg',
        ).writeAsStringSync(syntheticProjectIcon(shapes: '<g/>')),
      );
      expect(() => readProjectIcons(root.path), throwsGeneratorError('<g>'));
    });

    test('a missing folder stops the generator', () {
      final root = Directory.systemTemp.createTempSync('project_icons_test_');
      addTearDown(() => root.deleteSync(recursive: true));
      expect(
        () => readProjectIcons(root.path),
        throwsGeneratorError(projectIconsDirectory),
      );
    });
  });
}
