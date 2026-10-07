import 'package:flutter_test/flutter_test.dart';

import 'dart_source.dart';

// Pack files are only ever read (D-061, PRD section 9.1 rule 1): one file
// opens them, read-only and immutable, and nothing in the data layer can
// write SQL or files of a pack.

const _database = 'lib/data/services/pack_database.dart';

final _directive = RegExp(r'^\s*(?:import|export)\s+([^;]+);', multiLine: true);
final _quoted = RegExp('''['"]([^'"]+)['"]''');
final _sqliteOpen = RegExp(r'\bsqlite3\s*\.\s*(open\w*)\s*\(');

final _forbiddenInData = {
  'execute': RegExp(r'\.\s*execute\b'),
  'openInMemory': RegExp(r'\bopenInMemory\b'),
  'backup': RegExp(r'\bbackup\b'),
  'copyIntoMemory': RegExp(r'\bcopyIntoMemory\b'),
  'a writable OpenMode': RegExp(r'\bOpenMode\s*\.\s*readWrite\w*'),
};

final _sqlWrite = RegExp(
  r'\b(INSERT|UPDATE|DELETE|REPLACE|CREATE|DROP|ALTER|ATTACH|DETACH|VACUUM|'
  r'REINDEX)\b',
  caseSensitive: false,
);

/// `PRAGMA x = v` and `PRAGMA x(v)` set a value; reads that take an argument
/// use the `pragma_x(...)` table functions instead.
final _pragmaSet = RegExp(r'\bPRAGMA\s+[\w.]+\s*[=(]', caseSensitive: false);

final _fileWrite = RegExp(
  r'\.\s*(writeAsBytes|writeAsBytesSync|writeAsString|writeAsStringSync|'
  r'openWrite|writeFrom|writeFromSync|writeByte|writeByteSync|writeString|'
  r'writeStringSync|truncate|truncateSync|flush|flushSync|create|createSync|'
  r'createTemp|createTempSync|delete|deleteSync|rename|renameSync|copy|'
  r'copySync|setLastModified|setLastModifiedSync|setLastAccessed|'
  r'setLastAccessedSync)\b',
);
final _writableFileMode = RegExp(r'\bFileMode\s*\.\s*(?!read\b)\w+');

bool _isPackService(String path) =>
    RegExp(r'^lib/data/services/pack_[^/]*\.dart$').hasMatch(path);

/// The offset of the `)` closing the `(` at [open] in [code].
int _closing(String code, int open) {
  var depth = 0;
  for (var i = open; i < code.length; i++) {
    if (code[i] == '(') depth++;
    if (code[i] == ')' && --depth == 0) return i;
  }
  return code.length;
}

/// Broken rules, as `path:line: what`.
List<String> _violations(Map<String, String> sources) => [
  for (final MapEntry(key: path, value: source) in sources.entries)
    ..._violationsIn(path, source),
];

Iterable<String> _violationsIn(String path, String text) sync* {
  final source = ScannedSource(text);
  String at(int offset) => '$path:${source.lineOf(offset)}';

  if (path != _database) {
    for (final directive in _directive.allMatches(text)) {
      for (final uri in _quoted.allMatches(directive[1]!)) {
        if (uri[1]!.startsWith('package:sqlite3')) {
          yield '${at(directive.start)}: imports ${uri[1]}';
        }
      }
    }
  }

  for (final call in _sqliteOpen.allMatches(source.code)) {
    if (call[1] != 'open') continue;
    final open = call.end - 1;
    final arguments = source.code.substring(open, _closing(source.code, open));
    final strings = ScannedSource(
      text.substring(open + 1, open + arguments.length),
    ).strings.map((s) => s.value);
    bool inUri(String parameter) =>
        strings.any(RegExp('[?&]${RegExp.escape(parameter)}(?:&|\$)').hasMatch);
    if (!inUri('mode=ro')) yield '${at(call.start)}: open without mode=ro';
    if (!inUri('immutable=1')) {
      yield '${at(call.start)}: open without immutable=1';
    }
    if (!RegExp(r'\buri\s*:\s*true\b').hasMatch(arguments)) {
      yield '${at(call.start)}: open without uri: true';
    }
    if (!RegExp(
      r'\bmode\s*:\s*OpenMode\s*\.\s*readOnly\b',
    ).hasMatch(arguments)) {
      yield '${at(call.start)}: open without OpenMode.readOnly';
    }
  }

  if (path.startsWith('lib/data/')) {
    for (final MapEntry(key: name, value: pattern)
        in _forbiddenInData.entries) {
      for (final match in pattern.allMatches(source.code)) {
        yield '${at(match.start)}: $name';
      }
    }
    for (final literal in source.strings) {
      for (final match in _sqlWrite.allMatches(literal.value)) {
        yield '$path:${literal.line}: SQL ${match[1]}';
      }
      if (_pragmaSet.hasMatch(literal.value)) {
        yield '$path:${literal.line}: a PRAGMA that sets a value';
      }
    }
  }

  if (_isPackService(path)) {
    for (final match in _fileWrite.allMatches(source.code)) {
      yield '${at(match.start)}: .${match[1]}';
    }
    for (final match in _writableFileMode.allMatches(source.code)) {
      yield '${at(match.start)}: '
          '${match[0]!.replaceAll(RegExp(r'\s'), '')}';
    }
  }
}

void main() {
  test('lib/ opens packs read-only and never writes to them', () {
    final sources = dartSources('lib');
    expect(sources, isNotEmpty);
    expect(_violations(sources), isEmpty);
  });

  test('the pack database opens its file with sqlite3.open', () {
    final source = ScannedSource(dartSources('lib/data/services')[_database]!);
    expect(
      _sqliteOpen.allMatches(source.code).where((m) => m[1] == 'open'),
      isNotEmpty,
    );
  });

  group('the checker flags', () {
    const repository = 'lib/data/repositories/r.dart';
    const service = 'lib/data/services/pack_x.dart';

    test('package:sqlite3 outside the pack database', () {
      expect(
        _violations({
          repository: '''
import 'package:sqlite3/sqlite3.dart';
export 'package:sqlite3/common.dart';
import 'a.dart' if (dart.library.ffi) 'package:sqlite3_flutter_libs/x.dart';
''',
          _database: "import 'package:sqlite3/sqlite3.dart';",
        }),
        [
          '$repository:1: imports package:sqlite3/sqlite3.dart',
          '$repository:2: imports package:sqlite3/common.dart',
          '$repository:3: imports package:sqlite3_flutter_libs/x.dart',
        ],
      );
    });

    test('an open that is not read-only, immutable and by URI', () {
      expect(
        _violations({
          _database: '''
final ok = sqlite3.open(
  'file:\${Uri.file(path).path}?mode=ro&immutable=1',
  mode: OpenMode.readOnly,
  uri: true,
);
final a = sqlite3.open(path);
final b = sqlite3.open(
  'file:\$path?immutable=1&mode=rw', // mode=ro
  mode: OpenMode.readOnly,
  uri: true,
);
final c = sqlite3.open('file:\$path?mode=ro&immutable=1', uri: false);
''',
        }),
        [
          '$_database:6: open without mode=ro',
          '$_database:6: open without immutable=1',
          '$_database:6: open without uri: true',
          '$_database:6: open without OpenMode.readOnly',
          '$_database:7: open without mode=ro',
          '$_database:12: open without uri: true',
          '$_database:12: open without OpenMode.readOnly',
        ],
      );
    });

    test('execution, in-memory copies and backups in lib/data/', () {
      expect(
        _violations({
          repository: '''
db.execute(sql);
db..execute(sql);
final m = sqlite3.openInMemory();
final s = db.backup(other);
final c = sqlite3.copyIntoMemory(db);
final w = OpenMode.readWriteCreate;
''',
          'lib/ui/core/widgets/w.dart': 'controller.execute(x);',
        }),
        [
          '$repository:1: execute',
          '$repository:2: execute',
          '$repository:3: openInMemory',
          '$repository:4: backup',
          '$repository:5: copyIntoMemory',
          '$repository:6: a writable OpenMode',
        ],
      );
    });

    test('SQL that writes, and PRAGMAs that set, in lib/data/', () {
      expect(
        _violations({
          repository: '''
final a = db.select('SELECT number FROM surah');
final b = db.select('PRAGMA user_version');
final c = 'insert into ayah values (1)';
final d = """
  UPDATE ayah SET text = ?;
  DELETE FROM word""";
final e = 'REPLACE INTO x VALUES (1)';
final f = 'CREATE TABLE x (a)' 'DROP TABLE x';
final g = 'ALTER TABLE x ADD b; ATTACH ? AS y; DETACH y; VACUUM; REINDEX';
final h = 'PRAGMA user_version = 2';
final i = 'pragma journal_mode(WAL)';
final j = 'SELECT * FROM pragma_table_info(?)';
''',
        }),
        [
          '$repository:3: SQL insert',
          '$repository:4: SQL UPDATE',
          '$repository:4: SQL DELETE',
          '$repository:7: SQL REPLACE',
          '$repository:8: SQL CREATE',
          '$repository:8: SQL DROP',
          '$repository:9: SQL ALTER',
          '$repository:9: SQL ATTACH',
          '$repository:9: SQL DETACH',
          '$repository:9: SQL VACUUM',
          '$repository:9: SQL REINDEX',
          '$repository:10: a PRAGMA that sets a value',
          '$repository:11: a PRAGMA that sets a value',
        ],
      );
    });

    test('a dart:io write in lib/data/services/pack_*.dart', () {
      const writes = '''
await file.writeAsBytes(b);
file.writeAsStringSync(s);
final sink = file.openWrite();
final h = file.openSync(mode: FileMode.append);
final r = file.openSync(mode: FileMode.read);
await raf.writeFrom(b);
await File(p).create();
dir.createTempSync();
await file.delete();
file.renameSync(p);
await file.copy(p);
raf.truncateSync(0);
await raf.flush();
file.setLastModifiedSync(t);
final o = BytesBuilder(copy: false);
''';
      expect(
        _violations({service: writes, 'lib/data/services/other.dart': writes}),
        [
          '$service:1: .writeAsBytes',
          '$service:2: .writeAsStringSync',
          '$service:3: .openWrite',
          '$service:6: .writeFrom',
          '$service:7: .create',
          '$service:8: .createTempSync',
          '$service:9: .delete',
          '$service:10: .renameSync',
          '$service:11: .copy',
          '$service:12: .truncateSync',
          '$service:13: .flush',
          '$service:14: .setLastModifiedSync',
          '$service:4: FileMode.append',
        ],
      );
    });

    test('nothing in comments', () {
      expect(
        _violations({
          service: '''
// db.execute('INSERT'); file.writeAsBytes(b); sqlite3.open(path);
/* import 'package:sqlite3/sqlite3.dart'; */
''',
        }),
        isEmpty,
      );
    });
  });
}
