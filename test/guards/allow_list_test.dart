import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'allow_list.dart';
import 'contrast_pairs.dart';
import 'dart_source.dart';

const _allow = 'test/guards/allow';
const _quranText = 'lib/ui/core/widgets/quran_text.dart';
const _surahName = 'lib/ui/core/widgets/surah_name.dart';

/// A temporary folder holding [files], name to content.
String _folder(Map<String, String> files) {
  final directory = Directory.systemTemp.createTempSync('allow_list_test');
  addTearDown(() => directory.deleteSync(recursive: true));
  for (final MapEntry(key: name, value: text) in files.entries) {
    File('${directory.path}/$name').writeAsStringSync(text);
  }
  return directory.path;
}

/// A temporary copy of the `m0-` entries of [folder]: the ones migrated from
/// the constants the guards held before D-114.
String _migrated(String folder) => _folder({
  for (final file in Directory(folder).listSync().whereType<File>())
    if (file.uri.pathSegments.last.startsWith('m0-'))
      file.uri.pathSegments.last: file.readAsStringSync(),
});

Matcher _fails(List<String> problems) => throwsA(
  isA<AllowListError>().having((e) => e.problems, 'problems', problems),
);

void main() {
  group('the migrated entries equal the constants they replace', () {
    test('pack text', () {
      Set<String> load(String kind) => PathAllowList.load(
        _migrated('$_allow/pack_text/$kind'),
      ).entries.toSet();
      expect(load('sinks'), {_quranText, _surahName});
      expect(load('producers'), {
        'lib/data/services/pack_database.dart',
        'lib/ui/core/gallery/gallery_samples.dart',
      });
      expect(load('verifiers'), {
        'lib/data/repositories/local_pack_repository.dart',
        'lib/domain/models/verified_pack.dart',
      });
      expect(load('carriers'), {
        'lib/domain/models/pack_text.dart',
        'lib/data/services/pack_database.dart',
        'lib/data/repositories/*quran_text*.dart',
      });
    });

    test('the carrier pattern matches what the old expression matched', () {
      final old = RegExp(r'^lib/data/repositories/[^/]*quran_text[^/]*\.dart$');
      const glob = 'lib/data/repositories/*quran_text*.dart';
      final paths = [
        ...dartSources('lib').keys,
        'lib/data/repositories/quran_text.dart',
        'lib/data/repositories/x_quran_text_y.dart',
        'lib/data/repositories/sub/quran_text.dart',
        'lib/data/repositories/quran_text.dart.bak',
        'lib/data/repositories/quran_textXdart',
        'lib/data/services/quran_text.dart',
      ];
      for (final path in paths) {
        expect(
          PathAllowList.covers(glob, path),
          old.hasMatch(path),
          reason: path,
        );
      }
    });

    test('imports', () {
      expect(loadPackageAllowList(_migrated('$_allow/imports/non_plugins')), {
        'package:holyquran/',
        'package:flutter/',
        'package:flutter_localizations/',
        'package:go_router/',
        'package:intl/',
        'package:meta/',
        'package:collection/',
        'package:provider/',
      });
      expect(
        PathAllowList.load(_migrated('$_allow/imports/ramps')).entries.toSet(),
        {
          'lib/ui/core/widgets/mark.dart',
          'lib/ui/core/widgets/lockup.dart',
          'lib/ui/core/widgets/button.dart',
          'lib/ui/core/widgets/ayah_marker.dart',
          _quranText,
          'lib/ui/core/widgets/progress_bar.dart',
          'lib/ui/core/widgets/mini_player.dart',
          'lib/ui/core/widgets/continue_card.dart',
          'lib/ui/core/widgets/share_card.dart',
          'lib/ui/core/widgets/home_header.dart',
          'lib/ui/core/widgets/splash.dart',
          'lib/ui/core/gallery/gallery_screen.dart',
        },
      );
    });

    test('contrast', () {
      final entries = ContrastEntries.load(_migrated('$_allow/contrast'));
      String line(ContrastPair p) =>
          '${p.use == ContrastUse.text ? 'text' : 'non-text'}: '
          '${contrastName(p)}';
      expect(entries.pairs.map(line).toSet(), _oldPairs);
      expect(entries.pairs, hasLength(_oldPairs.length));
      expect(entries.cardPairs.map(line).toSet(), _oldCardPairs);
      expect(entries.exceptions, _oldExceptions);
      expect(entries.pinned, _oldPinned);
    });
  });

  group('a path allow-list', () {
    test('loads files, folders and patterns in file-name order', () {
      final list = PathAllowList.load(
        _folder({
          'p1-03-b.txt': '$_quranText\ndecision: D-062\nWhy, in one line.\n',
          'm0-a.txt': 'lib/ui/core/widgets/\ndecision: D-114',
          'm0-c.txt': 'lib/ui/core/widgets/*_name.dart\ndecision: D-084\n',
        }),
      );
      expect(list.entries, [
        'lib/ui/core/widgets/',
        'lib/ui/core/widgets/*_name.dart',
        _quranText,
      ]);
      expect(list.allows('lib/ui/core/widgets/sub/x.dart'), isTrue);
      expect(list.allows('lib/ui/core/theme/x.dart'), isFalse);
      expect(PathAllowList.covers('lib/a/*_b.dart', 'lib/a/x_b.dart'), isTrue);
      expect(
        PathAllowList.covers('lib/a/*_b.dart', 'lib/a/c/x_b.dart'),
        isFalse,
      );
      expect(PathAllowList.covers(_quranText, '${_quranText}x'), isFalse);
    });

    test('is empty when its folder does not exist', () {
      expect(PathAllowList.load('$_allow/no_such_folder').entries, isEmpty);
    });

    test('fails on a malformed entry', () {
      expect(
        () => PathAllowList.load(
          _folder({
            'Bad_Name.txt': '$_quranText\ndecision: D-062\n',
            'm0-a.md': '$_quranText\ndecision: D-062\n',
            'm0-b.txt': '$_quranText\n',
            'm0-c.txt': '$_quranText\ndecision: D-62\n',
            'm0-d.txt': '$_quranText\n\ndecision: D-062\n',
            'm0-e.txt': ' $_quranText\ndecision: D-062\n',
            'm0-f.txt': '',
          }),
        ),
        _fails([
          'Bad_Name.txt: not named <task>-<what>.txt',
          'm0-a.md: not named <task>-<what>.txt',
          'm0-b.txt: no decision line',
          'm0-c.txt: line 2 is not "decision: D-xxx"',
          'm0-d.txt: empty line or surrounding spaces',
          'm0-e.txt: empty line or surrounding spaces',
          'm0-f.txt: empty line or surrounding spaces',
        ]),
      );
      expect(
        () => PathAllowList.load(
          _folder({
            'm0-g.txt': '$_quranText\ndecision: D-062\nOne.\nTwo.\n',
            'm0-h.txt': '/$_quranText\ndecision: D-062\n',
            'm0-i.txt': 'lib/../lib/main.dart\ndecision: D-062\n',
            'm0-j.txt': 'lib/*/main.dart\ndecision: D-062\n',
            'm0-k.txt': 'lib\\main.dart\ndecision: D-062\n',
            'm0-l.txt': 'lib/*/\ndecision: D-062\n',
          }),
        ),
        _fails([
          'm0-g.txt: $_quranText has more than three lines',
          'm0-h.txt: /$_quranText is not a relative path',
          'm0-i.txt: lib/../lib/main.dart is not a relative path',
          'm0-j.txt: lib/*/main.dart is not a relative path',
          'm0-k.txt: lib\\main.dart is not a relative path',
          'm0-l.txt: lib/*/ is not a relative path',
        ]),
      );
    });

    test('fails on a path that does not exist', () {
      expect(
        () => PathAllowList.load(
          _folder({
            'm0-a.txt': 'lib/no_such_file.dart\ndecision: D-062\n',
            'm0-b.txt': 'lib/no_such_folder/\ndecision: D-062\n',
            'm0-c.txt': 'lib/ui/core/widgets/*_nothing.dart\ndecision: D-062\n',
            'm0-d.txt': 'lib/no_such_folder/*.dart\ndecision: D-062\n',
            'm0-e.txt': '$_quranText\ndecision: D-062\n',
          }),
        ),
        _fails([
          'm0-a.txt: lib/no_such_file.dart does not exist',
          'm0-b.txt: lib/no_such_folder/ does not exist',
          'm0-c.txt: lib/ui/core/widgets/*_nothing.dart matches no file',
          'm0-d.txt: lib/no_such_folder/*.dart matches no file',
        ]),
      );
    });

    test('fails on a path listed twice', () {
      expect(
        () => PathAllowList.load(
          _folder({
            'm0-a.txt': '$_quranText\ndecision: D-062\n',
            'p1-03-a.txt': '$_quranText\ndecision: D-114\n',
          }),
        ),
        _fails(['p1-03-a.txt: $_quranText also listed in m0-a.txt']),
      );
    });

    test('names the folder and every problem in its message', () {
      final folder = _folder({'m0-a.txt': 'lib/x.dart\n'});
      expect(
        () => PathAllowList.load(folder),
        throwsA(
          isA<AllowListError>().having(
            (e) => e.toString(),
            'message',
            'Allow-list $folder:\nm0-a.txt: no decision line',
          ),
        ),
      );
    });
  });

  group('a package allow-list', () {
    test('loads package prefixes', () {
      expect(
        loadPackageAllowList(
          _folder({'m0-a.txt': 'package:meta/\ndecision: D-114\n'}),
        ),
        {'package:meta/'},
      );
    });

    test('fails on a malformed or unresolved package', () {
      expect(
        () => loadPackageAllowList(
          _folder({
            'm0-a.txt': 'package:meta\ndecision: D-114\n',
            'm0-b.txt': 'package:no_such_package/\ndecision: D-114\n',
            'm0-c.txt': 'lib/main.dart\ndecision: D-114\n',
            'm0-d.txt': 'package:meta/\ndecision: D-114\nOne.\nTwo.\n',
          }),
        ),
        _fails([
          'm0-a.txt: package:meta is not package:<name>/',
          'm0-b.txt: package:no_such_package/ does not resolve',
          'm0-c.txt: lib/main.dart is not package:<name>/',
          'm0-d.txt: package:meta/ has more than three lines',
        ]),
      );
    });

    test('fails on a package listed twice', () {
      expect(
        () => loadPackageAllowList(
          _folder({
            'm0-intl.txt': 'package:intl/\ndecision: D-047\n',
            'p1-03-intl.txt': 'package:intl/\ndecision: D-114\n',
          }),
        ),
        _fails(['p1-03-intl.txt: package:intl/ also listed in m0-intl.txt']),
      );
    });
  });

  group('a contrast allow-list', () {
    test('reads pairs, card pairs and their ratios', () {
      final entries = ContrastEntries.load(
        _folder({
          'm0-a.txt':
              'non-text: x on y over z\ndecision: D-089\n'
              'exception: paper 1.50\npinned: night 3.25\nWhy.\n',
          'm0-b.txt': 'card text: x on y\ndecision: D-089\npinned: card 4.90\n',
        }),
      );
      expect(entries.pairs, [
        (fg: 'x', bg: 'y', over: 'z', use: ContrastUse.nonText),
      ]);
      expect(entries.cardPairs, [
        (fg: 'x', bg: 'y', over: null, use: ContrastUse.text),
      ]);
      expect(entries.exceptions, {'paper: x on y over z': 1.50});
      expect(entries.pinned, {
        'night: x on y over z': 3.25,
        'card: x on y': 4.90,
      });
    });

    test('fails on a malformed entry or a pair listed twice', () {
      expect(
        () => ContrastEntries.load(
          _folder({
            'm0-a.txt': 'ink on ground\ndecision: D-114\n',
            'm0-b.txt': 'text: ink on ground\ndecision: D-114\nWhy.\nMore.\n',
            'm0-c.txt':
                'text: ink on surface\ndecision: D-114\n'
                'exception: paper 1.5\nWhy.\n',
            'm0-d.txt':
                'text: ink on line\ndecision: D-114\n'
                'exception: paper 1.50\npinned: paper 1.50\n',
            'p1-03-a.txt': 'non-text: ink on ground\ndecision: D-114\n',
          }),
        ),
        _fails([
          'm0-a.txt: line 1 is not "[card ]<use>: a on b"',
          'm0-b.txt: "Why." is not a ratio line',
          'm0-c.txt: "exception: paper 1.5" is not a ratio line',
          'm0-d.txt: paper given twice',
          'p1-03-a.txt: ink on ground also listed in m0-b.txt',
        ]),
      );
    });
  });
}

List<String> _each(List<String> fgs, List<String> bgs, String use) => [
  for (final fg in fgs)
    for (final bg in bgs) '$use: $fg on $bg',
];

const _tajweed = [
  'tj-ghunna',
  'tj-idgham',
  'tj-ikhfa',
  'tj-iqlab',
  'tj-qalqala',
  'tj-madd-tabii',
  'tj-madd-wajib',
  'tj-madd-lazim',
];

/// `_pairs` of contrast_test.dart before D-114.
final _oldPairs = {
  ..._each(['ink'], ['ground', 'surface', 'surface-sunk'], 'text'),
  ..._each(
    ['ink-muted', 'quran-ink', 'primary', 'accent', 'success', 'error', 'info'],
    ['ground', 'surface'],
    'text',
  ),
  ..._each(['brand-ink'], ['ground'], 'text'),
  ..._each(['on-primary'], ['primary'], 'text'),
  ..._each(['on-primary-soft'], ['primary-soft'], 'text'),
  ..._each(
    ['on-player', 'on-player-muted', 'player-accent'],
    ['player'],
    'text',
  ),
  ..._each(['player'], ['on-player'], 'text'),
  ..._each(['emerald-950'], ['player-accent', 'ornament'], 'text'),
  ..._each(['gold-text-strong'], ['gold-100'], 'text'),
  ..._each(['ink'], ['warning-soft'], 'text'),
  ..._each(['ink-muted'], ['surface-sunk'], 'text'),
  ..._each(_tajweed, ['ground', 'surface'], 'text'),
  ..._each(
    [
      'warning',
      'ornament',
      'line-strong',
      'selection-line',
      'highlight-word-line',
    ],
    ['ground', 'surface'],
    'non-text',
  ),
  ..._each(['focus'], ['ground', 'surface', 'surface-sunk'], 'non-text'),
  ..._each(['on-primary-soft'], ['surface'], 'text'),
  ..._each(['paper-100'], ['emerald-700'], 'text'),
  ..._each(['line'], ['ground', 'surface'], 'non-text'),
  ..._each(['surface'], ['line'], 'non-text'),
  ..._each(['primary'], ['surface-sunk'], 'non-text'),
  ..._each(['gold-400'], ['emerald-700', 'emerald-950'], 'non-text'),
  ..._each(['night-ink'], ['emerald-950'], 'non-text'),
  'text: on-player on paper-100@14 over player',
  'non-text: player-accent on paper-100@22 over player',
  ..._each(['primary'], ['line'], 'non-text'),
  ..._each(['ornament'], ['primary-soft'], 'non-text'),
  ..._each(['primary-soft'], ['surface', 'ground'], 'non-text'),
};

/// `_cardPairs` of contrast_test.dart before D-114.
final _oldCardPairs = {
  ..._each(['gold-400'], ['emerald-700'], 'text'),
  ..._each(['paper-accent'], ['paper-ground'], 'text'),
  ..._each(['paper-ornament'], ['paper-ground'], 'non-text'),
};

/// `_exceptions` of contrast_test.dart before D-114.
const _oldExceptions = {
  'paper: ornament on ground': 2.90,
  'paper: player-accent on player': 3.90,
  'sepia: player-accent on player': 3.90,
  'sepia: emerald-950 on ornament': 3.10,
  'paper: tj-ghunna on ground': 4.43,
  'sepia: tj-ghunna on ground': 3.85,
  'sepia: tj-iqlab on ground': 4.22,
  'sepia: tj-madd-wajib on ground': 3.99,
  'sepia: tj-ghunna on surface': 4.24,
  'sepia: tj-madd-wajib on surface': 4.39,
  'paper: line on ground': 1.35,
  'paper: line on surface': 1.45,
  'night: line on ground': 1.54,
  'night: line on surface': 1.36,
  'sepia: line on ground': 1.31,
  'sepia: line on surface': 1.45,
  'paper: surface on line': 1.45,
  'night: surface on line': 1.36,
  'sepia: surface on line': 1.45,
  'paper: player-accent on paper-100@22 over player': 2.35,
  'sepia: player-accent on paper-100@22 over player': 2.35,
  'contrast: primary on line': 1.41,
  'paper: ornament on primary-soft': 2.54,
  'paper: primary-soft on surface': 1.23,
  'paper: primary-soft on ground': 1.14,
  'night: primary-soft on surface': 1.35,
  'night: primary-soft on ground': 1.52,
  'sepia: primary-soft on surface': 1.14,
  'sepia: primary-soft on ground': 1.03,
  'contrast: primary-soft on surface': 1.42,
  'contrast: primary-soft on ground': 1.72,
  'card: gold-400 on emerald-700': 3.90,
  'card: paper-ornament on paper-ground': 2.90,
};

/// `_pinned` of contrast_test.dart before D-114.
const _oldPinned = {
  'paper: on-player on paper-100@14 over player': 5.23,
  'night: on-player on paper-100@14 over player': 8.55,
  'sepia: on-player on paper-100@14 over player': 5.00,
  'contrast: on-player on paper-100@14 over player': 15.92,
  'night: player-accent on paper-100@22 over player': 4.10,
  'contrast: player-accent on paper-100@22 over player': 8.64,
  'paper: primary on line': 5.37,
  'night: primary on line': 5.89,
  'sepia: primary on line': 4.78,
  'night: ornament on primary-soft': 5.95,
  'sepia: ornament on primary-soft': 3.56,
  'contrast: ornament on primary-soft': 8.65,
  'card: paper-accent on paper-ground': 4.90,
};
