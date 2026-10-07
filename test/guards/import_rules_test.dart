import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _package = 'package:holyquran/';

final _directive = RegExp(r'^\s*(?:import|export)\s+([^;]+);', multiLine: true);
final _quoted = RegExp('''['"]([^'"]+)['"]''');

/// The URIs a Dart source imports or exports, conditional ones included.
/// Paths inside this package come back as `lib/...`.
List<String> _importsOf(String path, String source) => [
  for (final directive in _directive.allMatches(source))
    for (final uri in _quoted.allMatches(directive[1]!))
      _normalise(path, uri[1]!),
];

String _normalise(String fromPath, String uri) {
  if (uri.startsWith(_package)) return 'lib/${uri.substring(_package.length)}';
  if (uri.contains(':')) return uri;
  return Uri(path: '/$fromPath').resolve(uri).path.substring(1);
}

/// Broken rules of docs/ARCHITECTURE.md "Import rules", as `path: uri`.
List<String> _violations(Map<String, String> sources) => [
  for (final MapEntry(key: path, value: source) in sources.entries)
    for (final uri in _importsOf(path, source))
      if (_breaks(path, uri)) '$path: $uri',
];

bool _breaks(String path, String uri) {
  if (uri.endsWith('/ramps.g.dart') && !path.startsWith('lib/ui/core/')) {
    return true;
  }
  if (path.startsWith('lib/domain/')) {
    return uri.startsWith('package:flutter') ||
        uri == 'dart:ui' ||
        uri.startsWith('lib/data/') ||
        uri.startsWith('lib/ui/');
  }
  if (path.startsWith('lib/ui/')) {
    return uri.startsWith('lib/data/services/') || uri == 'dart:io';
  }
  return false;
}

Map<String, String> _libSources() => {
  for (final file in Directory(
    'lib',
  ).listSync(recursive: true).whereType<File>())
    if (file.path.endsWith('.dart'))
      file.path.replaceAll(r'\', '/'): file.readAsStringSync(),
};

void main() {
  test('lib/ follows the import rules', () {
    final sources = _libSources();
    expect(sources, isNotEmpty);
    expect(_violations(sources), isEmpty);
  });

  group('the checker flags', () {
    test('ramps.g.dart imported outside lib/ui/core/', () {
      const feature = 'lib/ui/features/home/views/home_screen.dart';
      expect(
        _violations({
          feature: "import 'package:holyquran/ui/core/theme/ramps.g.dart';",
          'lib/ui/core/widgets/mark.dart': "import '../theme/ramps.g.dart';",
          'lib/ui/core/theme/app_theme.dart': "import 'ramps.g.dart';",
        }),
        ['$feature: lib/ui/core/theme/ramps.g.dart'],
      );
    });

    test('Flutter, data or ui imported by the domain', () {
      expect(
        _violations({
          'lib/domain/models/a.dart': '''
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'dart:ui';
export '../../data/repositories/b.dart';
import 'package:holyquran/ui/core/app.dart';
import 'c.dart';
''',
        }),
        [
          'lib/domain/models/a.dart: package:flutter/foundation.dart',
          'lib/domain/models/a.dart: dart:ui',
          'lib/domain/models/a.dart: lib/data/repositories/b.dart',
          'lib/domain/models/a.dart: lib/ui/core/app.dart',
        ],
      );
    });

    test('services or dart:io imported by the ui, also conditionally', () {
      expect(
        _violations({
          'lib/ui/features/x/views/x_screen.dart': '''
import 'dart:io';
import 'package:holyquran/data/repositories/r.dart';
import 'stub.dart' if (dart.library.io) '../../../../data/services/s.dart';
''',
        }),
        [
          'lib/ui/features/x/views/x_screen.dart: dart:io',
          'lib/ui/features/x/views/x_screen.dart: lib/data/services/s.dart',
        ],
      );
    });
  });
}
