import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'dart_source.dart';

// Pack text stays untouched on its way to the screen (D-062,
// docs/ARCHITECTURE.md "Keeping pack text untouched"). Comments and string
// literals are not scanned.

const _packText = 'lib/domain/models/pack_text.dart';
const _database = 'lib/data/services/pack_database.dart';

/// The sinks that may read `PackText.verbatim`. Adding one is a reviewed
/// change to this list.
const _sinks = {'lib/ui/core/widgets/quran_text.dart'};

/// The files that may create a `PackText`: the database, and the debug
/// gallery's synthetic sample.
const _producers = {_database, 'lib/ui/core/gallery/gallery_screen.dart'};

/// The only files that may construct a `VerifiedPack`: the repository that
/// verifies packs, and the model itself.
const _verifiers = {
  'lib/data/repositories/local_pack_repository.dart',
  'lib/domain/models/verified_pack.dart',
};

/// The files that carry `PackText` values from the file to the screen.
bool _carriesPackText(String path) =>
    path == _packText ||
    path == _database ||
    _sinks.contains(path) ||
    RegExp(
      r'^lib/data/repositories/[^/]*quran_text[^/]*\.dart$',
    ).hasMatch(path);

final _verbatim = RegExp(r'\bverbatim\b');
final _verifiedPack = RegExp(r'\bVerifiedPack\s*(?:\(|\.\s*new\b)');
final _fromPack = RegExp(r'\bfromPack\b');
final _normalising = RegExp(
  r'normali[sz]|unorm|\bNFK?[CD]\b|diacritic',
  caseSensitive: false,
);
final _stringChange = RegExp(
  r'\.\s*(trim|trimLeft|trimRight|toLowerCase|toUpperCase|replaceAll|'
  r'replaceAllMapped|replaceFirst|replaceFirstMapped|replaceRange|split|'
  r'splitMapJoin)\b',
);
final _directive = RegExp(r'^\s*(?:import|export)\s+([^;]+);', multiLine: true);
final _quoted = RegExp('''['"]([^'"]+)['"]''');

/// Broken rules, as `path:line: what`.
List<String> _violations(Map<String, String> sources) => [
  for (final MapEntry(key: path, value: source) in sources.entries)
    ..._violationsIn(path, source),
];

Iterable<String> _violationsIn(String path, String text) sync* {
  final source = ScannedSource(text);
  String at(Match match) => '$path:${source.lineOf(match.start)}';
  if (path != _packText && !_sinks.contains(path)) {
    for (final match in _verbatim.allMatches(source.code)) {
      yield '${at(match)}: verbatim outside a sink';
    }
  }
  if (path != _packText && !_producers.contains(path)) {
    for (final match in _fromPack.allMatches(source.code)) {
      yield '${at(match)}: fromPack outside a producer';
    }
  }
  if (!_verifiers.contains(path)) {
    for (final match in _verifiedPack.allMatches(source.code)) {
      yield '${at(match)}: VerifiedPack constructed outside verification';
    }
  }
  for (final match in _normalising.allMatches(source.code)) {
    yield '${at(match)}: normalisation ${match[0]}';
  }
  for (final directive in _directive.allMatches(text)) {
    for (final uri in _quoted.allMatches(directive[1]!)) {
      if (_normalising.hasMatch(uri[1]!)) {
        yield '$path:${source.lineOf(directive.start)}: '
            'normalisation package ${uri[1]}';
      }
    }
  }
  if (_carriesPackText(path)) {
    for (final match in _stringChange.allMatches(source.code)) {
      yield '${at(match)}: .${match[1]} in a file that carries pack text';
    }
  }
}

void main() {
  test('lib/ reads, creates and changes pack text only where allowed', () {
    final sources = dartSources('lib');
    expect(sources, isNotEmpty);
    expect(_violations(sources), isEmpty);
  });

  test('the listed files exist', () {
    for (final path in {_packText, ..._sinks, ..._producers, ..._verifiers}) {
      expect(File(path).existsSync(), isTrue, reason: path);
    }
    expect(
      dartSources('lib/data/repositories').keys.where(_carriesPackText),
      isNotEmpty,
    );
  });

  group('the checker flags', () {
    const view = 'lib/ui/features/home/views/home_screen.dart';
    const repository = 'lib/data/repositories/pack_quran_text_repository.dart';

    test('verbatim outside pack_text.dart and the sinks', () {
      expect(
        _violations({
          view: '''
final a = text.verbatim;
final b = text?.verbatim;
final c = texts.map((t) => t.verbatim);
final d = switch (text) { PackText(:final verbatim) => verbatim };
''',
          repository: 'final e = text.verbatim;',
          _packText: 'String get verbatim => _value;',
          for (final sink in _sinks) sink: 'TextSpan(text: text.verbatim);',
        }),
        [
          '$view:1: verbatim outside a sink',
          '$view:2: verbatim outside a sink',
          '$view:3: verbatim outside a sink',
          '$view:4: verbatim outside a sink',
          '$view:4: verbatim outside a sink',
          '$repository:1: verbatim outside a sink',
        ],
      );
    });

    test('PackText.fromPack outside its producers', () {
      expect(
        _violations({
          view: 'final a = PackText.fromPack(label);',
          repository: 'final f = PackText.fromPack;',
          _packText: 'const PackText.fromPack(this._value);',
          for (final producer in _producers)
            producer: 'final t = PackText.fromPack(s);',
        }),
        [
          '$view:1: fromPack outside a producer',
          '$repository:1: fromPack outside a producer',
        ],
      );
    });

    test('a VerifiedPack constructed outside verification', () {
      expect(
        _violations({
          view: '''
final a = VerifiedPack(directory: d, manifest: m, signatureChecked: false);
final b = const VerifiedPack (directory: d, manifest: m, signatureChecked: true);
final c = VerifiedPack.new;
final d = VerifiedPack . new(directory: d, manifest: m, signatureChecked: false);
Future<Result<VerifiedPack>> e() => f();
final VerifiedPack g = h;
''',
          for (final verifier in _verifiers)
            verifier:
                'return VerifiedPack(directory: d, manifest: m, '
                'signatureChecked: c);',
        }),
        [
          '$view:1: VerifiedPack constructed outside verification',
          '$view:2: VerifiedPack constructed outside verification',
          '$view:3: VerifiedPack constructed outside verification',
          '$view:4: VerifiedPack constructed outside verification',
        ],
      );
    });

    test('a normalising identifier or package anywhere in lib/', () {
      const service = 'lib/data/services/s.dart';
      const normaliser = 'package:holyquran/utils/text_normalizer.dart';
      expect(
        _violations({
          service: '''
import 'package:unorm_dart/unorm_dart.dart';
import 'package:holyquran/utils/text_normalizer.dart';
final a = unorm.nfc(s);
final b = s.normalize(NFKD);
final c = removeDiacritics(s);
final d = normalise(s);
''',
        }),
        [
          '$service:3: normalisation unorm',
          '$service:3: normalisation nfc',
          '$service:4: normalisation normaliz',
          '$service:4: normalisation NFKD',
          '$service:5: normalisation Diacritic',
          '$service:6: normalisation normalis',
          '$service:1: normalisation package package:unorm_dart/unorm_dart.dart',
          '$service:2: normalisation package $normaliser',
        ],
      );
    });

    test('a string change in a file that carries pack text', () {
      const other = 'lib/data/services/pack_file_service.dart';
      const changes = '''
final a = s.trim();
final b = s.trimLeft().trimRight();
final c = s.toLowerCase() + s.toUpperCase();
final d = s.replaceAll(x, y).replaceFirst(x, y);
final e = s.split(' ');
final f = s.splitMapJoin(x);
final g = list.map((s) => s.trim);
''';
      final violations = _violations({
        for (final path in [_database, repository, ..._sinks, _packText])
          path: changes,
        other: changes,
      });
      expect(violations.where((v) => v.startsWith('$_database:')), [
        '$_database:1: .trim in a file that carries pack text',
        '$_database:2: .trimLeft in a file that carries pack text',
        '$_database:2: .trimRight in a file that carries pack text',
        '$_database:3: .toLowerCase in a file that carries pack text',
        '$_database:3: .toUpperCase in a file that carries pack text',
        '$_database:4: .replaceAll in a file that carries pack text',
        '$_database:4: .replaceFirst in a file that carries pack text',
        '$_database:5: .split in a file that carries pack text',
        '$_database:6: .splitMapJoin in a file that carries pack text',
        '$_database:7: .trim in a file that carries pack text',
      ]);
      expect(violations.map((v) => v.split(':').first).toSet(), {
        _database,
        repository,
        ..._sinks,
        _packText,
      });
    });

    test('nothing in comments or string literals', () {
      expect(
        _violations({
          view: '''
// text.verbatim, PackText.fromPack, normalize, s.trim(), VerifiedPack(
/// [PackText.verbatim], [VerifiedPack.new]
final a = 'verbatim fromPack NFC VerifiedPack(';
''',
          _database: "/* s.trim() */ final b = 'x.split(y)';",
        }),
        isEmpty,
      );
    });
  });
}
