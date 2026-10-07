import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _package = 'package:holyquran/';

/// Packages any layer may import. Everything else under `package:` counts as a
/// plugin; a new pure-Dart package is added here deliberately.
const _nonPlugins = [
  _package,
  'package:flutter/',
  'package:flutter_localizations/',
  'package:go_router/',
  'package:intl/',
  'package:meta/',
  'package:collection/',
];

/// The only files that may reach a raw colour ramp (docs/DESIGN_SYSTEM.md,
/// "Colour"): fixed brand surfaces, and the gallery's preview backdrops.
const _rampImporters = {
  'lib/ui/core/widgets/mark.dart',
  'lib/ui/core/widgets/lockup.dart',
  'lib/ui/core/widgets/button.dart',
  'lib/ui/core/widgets/ayah_marker.dart',
  'lib/ui/core/gallery/gallery_screen.dart',
};

const _databasePackages = [
  'package:drift',
  'package:sqlite3',
  'package:sqflite',
];

final _directive = RegExp(r'^\s*(?:import|export)\s+([^;]+);', multiLine: true);
final _quoted = RegExp('''['"]([^'"]+)['"]''');
final _feature = RegExp(r'^lib/ui/features/([^/]+)/');

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

/// Broken rules of docs/ARCHITECTURE.md "Import rules", as `path: uri (rule)`.
List<String> _violations(Map<String, String> sources) => [
  for (final MapEntry(key: path, value: source) in sources.entries)
    for (final uri in _importsOf(path, source))
      for (final rule in _rulesBroken(path, uri)) '$path: $uri ($rule)',
];

Iterable<String> _rulesBroken(String path, String uri) sync* {
  if (uri.endsWith('/ramps.g.dart') && !_rampImporters.contains(path)) {
    yield 'ramps';
  }
  if (uri.startsWith('package:') &&
      !_nonPlugins.any(uri.startsWith) &&
      !path.startsWith('lib/data/services/')) {
    yield 'plugin';
  }
  if (path.startsWith('lib/domain/') &&
      (uri.startsWith('package:flutter') ||
          uri == 'dart:ui' ||
          uri.startsWith('lib/data/') ||
          uri.startsWith('lib/ui/'))) {
    yield 'domain';
  }
  if (path.startsWith('lib/ui/')) {
    if (uri.startsWith('lib/data/services/') || uri == 'dart:io') yield 'ui';
    if (_databasePackages.any(uri.startsWith)) yield 'database';
  }
  final from = _feature.firstMatch(path)?[1];
  final to = _feature.firstMatch(uri)?[1];
  if (from != null && to != null && from != to) yield 'feature';
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
    test('ramps.g.dart imported by a file not on the allow-list', () {
      const feature = 'lib/ui/features/home/views/home_screen.dart';
      const coreWidget = 'lib/ui/core/widgets/tab_bar.dart';
      const theme = 'lib/ui/core/theme/app_theme.dart';
      const ramps = 'lib/ui/core/theme/ramps.g.dart';
      expect(
        _violations({
          feature: "import 'package:holyquran/ui/core/theme/ramps.g.dart';",
          coreWidget: "import '../theme/ramps.g.dart';",
          theme: "export 'ramps.g.dart';",
          for (final allowed in _rampImporters)
            allowed: "import 'package:holyquran/ui/core/theme/ramps.g.dart';",
        }),
        [
          '$feature: $ramps (ramps)',
          '$coreWidget: $ramps (ramps)',
          '$theme: $ramps (ramps)',
        ],
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
import 'package:meta/meta.dart';
import 'c.dart';
''',
        }),
        [
          'lib/domain/models/a.dart: package:flutter/foundation.dart (domain)',
          'lib/domain/models/a.dart: dart:ui (domain)',
          'lib/domain/models/a.dart: lib/data/repositories/b.dart (domain)',
          'lib/domain/models/a.dart: lib/ui/core/app.dart (domain)',
        ],
      );
    });

    test('services or dart:io imported by the ui, also conditionally', () {
      const screen = 'lib/ui/features/x/views/x_screen.dart';
      expect(
        _violations({
          screen: '''
import 'dart:io';
import 'package:holyquran/data/repositories/r.dart';
import 'stub.dart' if (dart.library.io) '../../../../data/services/s.dart';
''',
        }),
        ['$screen: dart:io (ui)', '$screen: lib/data/services/s.dart (ui)'],
      );
    });

    test('a plugin imported outside lib/data/services/', () {
      const view = 'lib/ui/features/home/views/home_screen.dart';
      const repository = 'lib/data/repositories/r.dart';
      const plugin = 'package:path_provider/path_provider.dart';
      const allowed = '''
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:meta/meta.dart';
import 'package:collection/collection.dart';
import 'package:holyquran/domain/models/m.dart';
''';
      expect(
        _violations({
          view: "$allowed import '$plugin';",
          repository: "export '$plugin';",
          'lib/domain/models/m.dart': "import 'package:flutter_foo/foo.dart';",
          'lib/data/services/s.dart': "$allowed import '$plugin';",
        }),
        [
          '$view: $plugin (plugin)',
          '$repository: $plugin (plugin)',
          'lib/domain/models/m.dart: package:flutter_foo/foo.dart (plugin)',
          'lib/domain/models/m.dart: package:flutter_foo/foo.dart (domain)',
        ],
      );
    });

    test('a feature folder importing another feature folder', () {
      const home = 'lib/ui/features/home/views/home_screen.dart';
      expect(
        _violations({
          home: '''
import '../../more/views/more_screen.dart';
import 'package:holyquran/ui/features/mushaf/view_models/m.dart';
import '../view_models/home_view_model.dart';
import '../../../core/widgets/w.dart';
import 'package:holyquran/ui/features/home/widgets/h.dart';
''',
        }),
        [
          '$home: lib/ui/features/more/views/more_screen.dart (feature)',
          '$home: lib/ui/features/mushaf/view_models/m.dart (feature)',
        ],
      );
    });

    test('a database package imported by the ui', () {
      const ui = 'lib/ui/core/widgets/w.dart';
      expect(
        _violations({
          ui: '''
import 'package:drift/drift.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqflite/sqflite.dart';
''',
          'lib/data/services/db.dart': "import 'package:drift/drift.dart';",
        }),
        [
          '$ui: package:drift/drift.dart (plugin)',
          '$ui: package:drift/drift.dart (database)',
          '$ui: package:sqlite3/sqlite3.dart (plugin)',
          '$ui: package:sqlite3/sqlite3.dart (database)',
          '$ui: package:sqflite/sqflite.dart (plugin)',
          '$ui: package:sqflite/sqflite.dart (database)',
        ],
      );
    });
  });
}
