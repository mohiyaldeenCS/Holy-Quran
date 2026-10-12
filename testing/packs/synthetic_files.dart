import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:sqlite3/sqlite3.dart';

import 'raw_pack.dart';

const manifestFileName = 'manifest.json';

/// The Arabic-script synthetic phrase of the test data: plainly not Quran
/// text.
const syntheticArabic =
    '\u{646}\u{635} \u{62A}\u{62C}\u{631}\u{64A}\u{628}\u{64A}';

/// Writes a pack data file as docs/CONTENT_PACKS.md requires: UTF-8,
/// `application_id` and `user_version` set before [schema] is created,
/// rollback journal, ending with `VACUUM`. [fill] runs inside one
/// transaction. With [wal], the file is left in WAL mode.
void writePackFile(
  File file, {
  required int userVersion,
  required List<String> schema,
  required void Function(Database db) fill,
  int applicationId = hqpkApplicationId,
  bool wal = false,
}) {
  final db = sqlite3.open(file.path);
  try {
    db
      ..execute("PRAGMA encoding = 'UTF-8'")
      ..execute('PRAGMA application_id = $applicationId')
      ..execute('PRAGMA user_version = $userVersion')
      ..execute('PRAGMA journal_mode = DELETE')
      ..execute('PRAGMA foreign_keys = ON');
    schema.forEach(db.execute);
    db.execute('BEGIN');
    fill(db);
    db
      ..execute('COMMIT')
      ..execute('VACUUM');
    if (wal) db.execute('PRAGMA journal_mode = WAL');
  } finally {
    db.close();
  }
}

/// A source entry of a synthetic manifest.
Map<String, Object?> syntheticSource(
  String role,
  int registryRow,
  Map<String, Object>? options,
) => {
  'role': role,
  'registry_row': registryRow,
  'name': 'Synthetic $role source',
  'publisher': 'Synthetic publisher',
  'url': 'https://example.invalid/synthetic/$role',
  'version': '1',
  'fetched_on': '2026-01-01',
  'file_sha256': sha256.convert(utf8.encode('synthetic $role')).toString(),
  'trust_grade': 'A',
  'options': options,
  'licence': {
    'text': null,
    'permission_ref': 'Synthetic permission $registryRow',
    'notice': null,
    'allows_export': true,
  },
};

/// The fields every kind's synthetic manifest shares, around [fields].
Map<String, Object?> syntheticManifest({
  required int formatVersion,
  required String id,
  required String kind,
  required int version,
  required Map<String, Object?> fields,
}) => jsonCopy({
  'format': 'holyquran-pack',
  'format_version': formatVersion,
  'id': id,
  'kind': kind,
  'version': version,
  'changelog': [
    {'version': version, 'date': '2026-01-01', 'summary': 'Synthetic pack'},
  ],
  'riwaya': 'hafs',
  ...fields,
  'reviews': [
    {
      'reviewer': 'synthetic reviewer',
      'date': '2026-01-01',
      'scope': 'synthetic test data',
    },
  ],
});

/// The `files` entry of [file].
Future<Map<String, Object?>> fileEntry(File file) async {
  final bytes = await file.readAsBytes();
  return {
    'name': file.uri.pathSegments.last,
    'sha256': sha256.convert(bytes).toString(),
    'bytes': bytes.length,
  };
}

Future<void> writeManifest(
  Directory directory,
  Map<String, Object?> manifest,
) => File('${directory.path}/$manifestFileName').writeAsBytes(
  utf8.encode('${const JsonEncoder.withIndent('  ').convert(manifest)}\n'),
);

/// A JSON round trip, so that a manifest shares no map with the stored
/// truth and equals what is written.
Map<String, Object?> jsonCopy(Map<String, Object?> map) =>
    jsonDecode(jsonEncode(map)) as Map<String, Object?>;
