import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/config/base_pack.dart';

import 'dart_source.dart';

// D-163, D-164: the unapproved test copy is switched on in one place, read
// before the app starts, fed from the phone's files and never bundled, so that
// no release build can hold a pack no one approved.

const _testCopy = 'lib/config/test_copy.dart';
const _main = 'lib/main.dart';
const _deviceBundle = 'lib/data/services/device_pack_bundle.dart';
const _defineName = 'HOLYQURAN_TEST_PACK';
const _packsAssets = 'assets/packs';

final _directive = RegExp(r'^\s*(?:import|export)\s+([^;]+);', multiLine: true);
final _quoted = RegExp('''['"]([^'"]+)['"]''');
final _testCopyRead = RegExp(r'\btestCopy\b');
final _runApp = RegExp(r'\brunApp\s*\(');
final _externalStorage = RegExp(r'\bgetExternalStorageDirectory\b');
final _assetValue = RegExp(r'^\s*(?:-\s+)?asset:\s*(\S+)\s*$');
final _plainItem = RegExp(r'^\s*-\s+([^\s:#]+)\s*$');

/// The files that name a define (`HOLYQURAN_TEST_PACK`, and the key's name
/// which begins with it) in a string, as `path:line`, other than
/// `lib/config/test_copy.dart`.
List<String> _defineReaders(Map<String, String> sources) => [
  for (final MapEntry(key: path, value: source) in sources.entries)
    if (path != _testCopy)
      for (final literal in ScannedSource(source).strings)
        if (literal.value.contains(_defineName)) '$path:${literal.line}',
];

/// What `main` must do: read `testCopy` once before it calls `runApp`.
/// Empty when it does, else why not.
List<String> _mainProblems(String source) {
  final code = ScannedSource(source).code;
  final run = _runApp.firstMatch(code);
  final read = _testCopyRead.firstMatch(code);
  return [
    if (run == null) '$_main never calls runApp',
    if (read == null) '$_main never reads testCopy',
    if (run != null && read != null && read.start > run.start)
      '$_main reads testCopy after runApp',
  ];
}

/// Uses of `getExternalStorageDirectory` in code, as `path:line`, outside
/// `lib/data/services/device_pack_bundle.dart`.
List<String> _externalStorageUses(Map<String, String> sources) => [
  for (final MapEntry(key: path, value: source) in sources.entries)
    if (path != _deviceBundle)
      for (final use in _externalStorage.allMatches(ScannedSource(source).code))
        '$path:${ScannedSource(source).lineOf(use.start)}',
];

/// The asset paths a `pubspec.yaml` lists under `flutter:`: every `asset:`
/// value and every plain list item of that section.
List<String> _flutterAssets(String pubspec) {
  final lines = pubspec.split('\n');
  final start = lines.indexWhere((line) => line.trimRight() == 'flutter:');
  if (start < 0) return const [];
  final paths = <String>[];
  for (final line in lines.skip(start + 1)) {
    if (line.isNotEmpty && !line.startsWith(RegExp(r'[ #]'))) break;
    final path =
        _assetValue.firstMatch(line)?[1] ?? _plainItem.firstMatch(line)?[1];
    if (path != null) paths.add(path.replaceAll(RegExp('[\'"]'), ''));
  }
  return paths;
}

/// Assets that put `assets/packs/` in the app, other than the directory of
/// [bundled], the pack the app bundles, as it holds one. An entry above
/// `assets/packs/` counts, since it takes the packs in with it.
List<String> _packAssets(
  String pubspec, {
  required ({String id, int version})? bundled,
}) {
  final allowed = bundled == null
      ? null
      : '$_packsAssets/${bundled.id}/${bundled.version}/';
  return [
    for (final path in _flutterAssets(pubspec))
      if (_holdsPacks(path) && (allowed == null || !path.startsWith(allowed)))
        path,
  ];
}

bool _holdsPacks(String path) {
  final folder = path.endsWith('/') ? path : '$path/';
  return folder.startsWith('$_packsAssets/') ||
      '$_packsAssets/'.startsWith(folder);
}

/// The imports of `lib/config/` by a file of `lib/ui/`, as `path: uri`.
List<String> _uiConfigImports(Map<String, String> sources) => [
  for (final MapEntry(key: path, value: source) in sources.entries)
    if (path.startsWith('lib/ui/'))
      for (final directive in _directive.allMatches(source))
        for (final uri in _quoted.allMatches(directive[1]!))
          if (_resolve(path, uri[1]!).startsWith('lib/config/'))
            '$path: ${uri[1]}',
];

String _resolve(String fromPath, String uri) {
  if (uri.startsWith('package:holyquran/')) {
    return 'lib/${uri.substring('package:holyquran/'.length)}';
  }
  if (uri.contains(':')) return uri;
  return Uri(path: '/$fromPath').resolve(uri).path.substring(1);
}

void main() {
  final lib = dartSources('lib');

  group('the real code', () {
    test('the defines are named only in lib/config/test_copy.dart', () {
      expect(lib, contains(_testCopy));
      expect(_defineReaders(lib), isEmpty);
    });

    test('test_copy.dart reads both defines', () {
      final names = ScannedSource(lib[_testCopy]!).strings
          .map((literal) => literal.value);
      expect(names, containsAll([_defineName, '${_defineName}_KEY']));
    });

    test('main reads testCopy before runApp', () {
      expect(_mainProblems(lib[_main]!), isEmpty);
    });

    test('getExternalStorageDirectory is called only by DevicePackBundle', () {
      expect(_externalStorageUses(lib), isEmpty);
      expect(
        _externalStorage.hasMatch(ScannedSource(lib[_deviceBundle]!).code),
        isTrue,
      );
    });

    test('pubspec.yaml lists nothing under assets/packs', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(_flutterAssets(pubspec), isNotEmpty);
      expect(bundledBasePack, isNull);
      expect(_packAssets(pubspec, bundled: bundledBasePack), isEmpty);
    });

    test('lib/ui imports nothing from lib/config', () {
      expect(lib.keys.where((path) => path.startsWith('lib/ui/')), isNotEmpty);
      expect(_uiConfigImports(lib), isEmpty);
    });
  });

  group('the checks flag', () {
    test(
      'a define named in another file, in a string and not in a comment',
      () {
        expect(
          _defineReaders({
            _testCopy: "const a = String.fromEnvironment('$_defineName');",
            'lib/main.dart':
                '''
// $_defineName is read elsewhere.
const a = bool.fromEnvironment('$_defineName');
''',
            'lib/config/other.dart':
                '''
const k = String.fromEnvironment("${_defineName}_KEY");
''',
            'lib/data/clean.dart': "const k = 'HOLYQURAN_OTHER';",
          }),
          ['lib/main.dart:2', 'lib/config/other.dart:1'],
        );
      },
    );

    test('main that reads testCopy after runApp, or not at all', () {
      expect(
        _mainProblems('''
void main() {
  runApp(const App());
  final copy = testCopy;
}
'''),
        ['$_main reads testCopy after runApp'],
      );
      expect(
        _mainProblems('''
// testCopy is read first.
void main() => runApp(const App());
'''),
        ['$_main never reads testCopy'],
      );
      expect(_mainProblems('void main() {}'), [
        '$_main never calls runApp',
        '$_main never reads testCopy',
      ]);
      expect(
        _mainProblems('''
void main() {
  final copy = testCopy != null;
  runApp(App(copy: copy));
}
'''),
        isEmpty,
      );
    });

    test('getExternalStorageDirectory called outside DevicePackBundle', () {
      expect(
        _externalStorageUses({
          _deviceBundle: 'final d = await getExternalStorageDirectory();',
          'lib/data/services/other.dart': '''
// getExternalStorageDirectory is not called here.
final d = await getExternalStorageDirectory();
''',
          'lib/ui/core/x.dart': '''
final d = getExternalStorageDirectory;
final s = 'getExternalStorageDirectory';
''',
        }),
        ['lib/data/services/other.dart:2', 'lib/ui/core/x.dart:1'],
      );
    });

    group('an asset of the pubspec', () {
      String pubspec(List<String> assets) =>
          '''
name: x
flutter:
  uses-material-design: true
  fonts:
    - family: F
      fonts:
        - asset: assets/fonts/F.ttf
  assets:
${[for (final asset in assets) '    - $asset'].join('\n')}
dependencies:
  assets/packs/not-an-asset/: 1
''';

      test('under assets/packs, or a folder holding it', () {
        expect(
          _packAssets(
            pubspec([
              'assets/licenses/',
              'assets/packs/unapproved-x/1/',
              'assets/packs/',
              'assets/',
            ]),
            bundled: null,
          ),
          ['assets/packs/unapproved-x/1/', 'assets/packs/', 'assets/'],
        );
      });

      test('a font, a licence and a sibling of packs pass', () {
        expect(
          _packAssets(
            pubspec(['assets/licenses/', 'assets/packs-notes/a.txt']),
            bundled: null,
          ),
          isEmpty,
        );
      });

      test('only the bundled base pack\'s directory is allowed', () {
        final text = pubspec([
          'assets/packs/hafs-base/3/',
          'assets/packs/unapproved-x/1/',
        ]);
        expect(_packAssets(text, bundled: (id: 'hafs-base', version: 3)), [
          'assets/packs/unapproved-x/1/',
        ]);
        expect(_packAssets(text, bundled: null), [
          'assets/packs/hafs-base/3/',
          'assets/packs/unapproved-x/1/',
        ]);
      });
    });

    test('lib/ui importing lib/config, by package URI or relative path', () {
      const feature = 'lib/ui/features/home/views/a.dart';
      expect(
        _uiConfigImports({
          feature: '''
import 'package:holyquran/config/test_copy.dart';
import '../../../../config/providers/share_providers.dart';
import 'package:holyquran/domain/models/unapproved_copy_mark.dart';
import 'package:holyquran/ui/core/app.dart';
''',
          'lib/routing/router.dart':
              "import 'package:holyquran/config/test_copy.dart';",
          'lib/ui/core/b.dart':
              "export 'package:holyquran/config/base_pack.dart';",
        }),
        [
          '$feature: package:holyquran/config/test_copy.dart',
          '$feature: ../../../../config/providers/share_providers.dart',
          'lib/ui/core/b.dart: package:holyquran/config/base_pack.dart',
        ],
      );
    });
  });
}
