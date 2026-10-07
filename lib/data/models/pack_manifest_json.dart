import 'dart:convert';

import '../../domain/models/edition_map.dart';
import '../../domain/models/pack_failure.dart';
import '../../domain/models/pack_manifest.dart';
import '../../domain/models/quran_address.dart';
import '../../utils/result.dart';

/// The pack format versions this app reads (docs/CONTENT_PACKS.md).
const supportedPackFormatVersion = 1;

/// The one data file of a text pack.
const textPackFileName = 'text.sqlite';

/// Parses the exact bytes of `manifest.json` (docs/CONTENT_PACKS.md,
/// "Manifest"): UTF-8 without a byte order mark, every field present, no
/// unknown field. [pack] names the pack in a failure.
Result<PackManifest> parsePackManifest(
  List<int> bytes, {
  required String pack,
}) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF) {
    return Failure(ManifestUnreadable(pack, 'begins with a byte order mark'));
  }
  final Object? json;
  try {
    json = jsonDecode(utf8.decode(bytes));
  } on FormatException catch (e) {
    return Failure(ManifestUnreadable(pack, 'not UTF-8 JSON: ${e.message}'));
  }
  if (json is! Map<String, Object?>) {
    return Failure(ManifestUnreadable(pack, 'not a JSON object'));
  }
  if (json['format'] != 'holyquran-pack') {
    return Failure(ManifestUnreadable(pack, 'format is not holyquran-pack'));
  }
  if (json['format_version'] case final int version
      when version != supportedPackFormatVersion) {
    return Failure(UnsupportedPackFormat(pack, version));
  } else if (json['format_version'] is! int) {
    return Failure(UnsupportedPackFormat(pack, null));
  }
  try {
    return Ok(_manifest(_Object(json, 'manifest')));
  } on _Invalid catch (e) {
    return Failure(ManifestUnreadable(pack, e.reason));
  }
}

PackManifest _manifest(_Object json) {
  json.expectKeys(const {
    'format',
    'format_version',
    'id',
    'kind',
    'version',
    'changelog',
    'riwaya',
    'edition',
    'font',
    'sources',
    'files',
    'surah_sha256',
    'counts',
    'reviews',
  });
  final kind = switch (json.string('kind')) {
    'text' => PackKind.text,
    _ => throw const _Invalid('kind is not a known kind'),
  };
  final riwaya = json.nullableString('riwaya');
  if (kind == PackKind.text && riwaya == null) {
    throw const _Invalid('riwaya of a text pack is null');
  }
  if (riwaya != null && !QuranAddress.riwayaPattern.hasMatch(riwaya)) {
    throw _Invalid(
      'riwaya is not of the form ${QuranAddress.riwayaPattern.pattern}',
    );
  }
  final counts = _counts(json.object('counts'));
  final files = [for (final file in json.objects('files')) _file(file)];
  if (kind == PackKind.text &&
      (files.length != 1 || files.single.name != textPackFileName)) {
    throw const _Invalid(
      'files of a text pack is not exactly $textPackFileName',
    );
  }
  final sources = [
    for (final source in json.objects('sources')) _source(source),
  ];
  if (sources.isEmpty) throw const _Invalid('sources is empty');
  if (kind == PackKind.text &&
      !sources.any((source) => source.role == SourceRole.text)) {
    throw const _Invalid('sources of a text pack has no text source');
  }
  return PackManifest(
    formatVersion: json.integer('format_version'),
    id: json.string('id'),
    kind: kind,
    version: json.positive('version'),
    changelog: [
      for (final change in json.objects('changelog')) _change(change),
    ],
    riwaya: riwaya,
    edition: json.string('edition'),
    font: _font(json.object('font')),
    sources: sources,
    files: files,
    surahSha256: _surahSha256(json.object('surah_sha256'), counts.surahs),
    counts: counts,
    reviews: [for (final review in json.objects('reviews')) _review(review)],
  );
}

PackChange _change(_Object json) {
  json.expectKeys(const {'version', 'date', 'summary'});
  return PackChange(
    version: json.positive('version'),
    date: json.date('date'),
    summary: json.string('summary'),
  );
}

PackFont _font(_Object json) {
  json.expectKeys(const {'family', 'version', 'sha256'});
  return PackFont(
    family: json.string('family'),
    version: json.string('version'),
    sha256: json.hash('sha256'),
  );
}

PackSource _source(_Object json) {
  json.expectKeys(const {
    'role',
    'registry_row',
    'name',
    'publisher',
    'url',
    'version',
    'fetched_on',
    'file_sha256',
    'trust_grade',
    'options',
    'licence',
  });
  return PackSource(
    role: switch (json.string('role')) {
      'text' => SourceRole.text,
      'edition_map' => SourceRole.editionMap,
      _ => throw _Invalid('${json.path}.role is not text or edition_map'),
    },
    registryRow: json.positive('registry_row'),
    name: json.string('name'),
    publisher: json.string('publisher'),
    url: json.string('url'),
    version: json.string('version'),
    fetchedOn: json.date('fetched_on'),
    fileSha256: json.hash('file_sha256'),
    trustGrade: switch (json.string('trust_grade')) {
      'A' => TrustGrade.a,
      'B' => TrustGrade.b,
      'C' => TrustGrade.c,
      _ => throw _Invalid('${json.path}.trust_grade is not A, B or C'),
    },
    options: json.nullableObject('options')?.scalars(),
    licence: _licence(json.object('licence')),
  );
}

PackLicence _licence(_Object json) {
  json.expectKeys(const {'text', 'permission_ref', 'notice', 'allows_export'});
  final text = json.nullableString('text');
  final permissionRef = json.nullableString('permission_ref');
  if (text == null && permissionRef == null) {
    throw _Invalid('${json.path} has neither text nor permission_ref');
  }
  return PackLicence(
    text: text,
    permissionRef: permissionRef,
    notice: json.nullableString('notice'),
    allowsExport: json.boolean('allows_export'),
  );
}

PackFile _file(_Object json) {
  json.expectKeys(const {'name', 'sha256', 'bytes'});
  final name = json.string('name');
  if (name.isEmpty ||
      name == '.' ||
      name.contains('/') ||
      name.contains(r'\') ||
      name.contains('..')) {
    throw _Invalid('${json.path}.name is not a bare file name');
  }
  return PackFile(
    name: name,
    sha256: json.hash('sha256'),
    bytes: json.count('bytes'),
  );
}

Map<int, String> _surahSha256(_Object json, int surahs) {
  json.expectKeys({for (var n = 1; n <= surahs; n++) '$n'});
  return {for (var n = 1; n <= surahs; n++) n: json.hash('$n')};
}

PackCounts _counts(_Object json) {
  json.expectKeys(const {
    'surahs',
    'ayat',
    'words',
    'marks',
    'divisions',
    'sajdas',
  });
  final divisions = json.object('divisions')
    ..expectKeys({for (final division in Division.values) division.name});
  return PackCounts(
    surahs: json.count('surahs'),
    ayat: json.count('ayat'),
    words: json.count('words'),
    marks: json.count('marks'),
    divisions: {
      for (final division in Division.values)
        division: divisions.count(division.name),
    },
    sajdas: json.count('sajdas'),
  );
}

PackReview _review(_Object json) {
  json.expectKeys(const {'reviewer', 'date', 'scope'});
  return PackReview(
    reviewer: json.string('reviewer'),
    date: json.date('date'),
    scope: json.string('scope'),
  );
}

final class _Invalid implements Exception {
  const _Invalid(this.reason);

  final String reason;
}

/// A JSON object and its path in the manifest, read field by field with the
/// type each field must have.
final class _Object {
  _Object(this._map, this.path);

  final Map<String, Object?> _map;
  final String path;

  static final _hash = RegExp(r'^[0-9a-f]{64}$');
  static final _date = RegExp(r'^([0-9]{4})-([0-9]{2})-([0-9]{2})$');

  void expectKeys(Set<String> keys) {
    for (final key in _map.keys) {
      if (!keys.contains(key)) throw _Invalid('$path has unknown field $key');
    }
    for (final key in keys) {
      if (!_map.containsKey(key)) throw _Invalid('$path lacks field $key');
    }
  }

  T _field<T>(String key, String type) => switch (_map[key]) {
    final T value => value,
    _ => throw _Invalid('$path.$key is not $type'),
  };

  String string(String key) => _field<String>(key, 'a string');

  String? nullableString(String key) =>
      _field<String?>(key, 'a string or null');

  bool boolean(String key) => _field<bool>(key, 'a boolean');

  int integer(String key) => _field<int>(key, 'an integer');

  int count(String key) {
    final value = integer(key);
    if (value < 0) throw _Invalid('$path.$key is negative');
    return value;
  }

  int positive(String key) {
    final value = integer(key);
    if (value < 1) throw _Invalid('$path.$key is not positive');
    return value;
  }

  String hash(String key) {
    final value = string(key);
    if (!_hash.hasMatch(value)) {
      throw _Invalid('$path.$key is not lowercase hex SHA-256');
    }
    return value;
  }

  String date(String key) {
    final value = string(key);
    final match = _date.firstMatch(value);
    if (match == null) throw _Invalid('$path.$key is not YYYY-MM-DD');
    final [year, month, day] = [
      for (final group in [1, 2, 3]) int.parse(match[group]!),
    ];
    final parsed = DateTime.utc(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      throw _Invalid('$path.$key is not a calendar date');
    }
    return value;
  }

  _Object object(String key) =>
      _Object(_field<Map<String, Object?>>(key, 'an object'), '$path.$key');

  _Object? nullableObject(String key) =>
      switch (_field<Map<String, Object?>?>(key, 'an object or null')) {
        final map? => _Object(map, '$path.$key'),
        null => null,
      };

  /// Every field, each a string, a number or a boolean.
  Map<String, Object> scalars() => {
    for (final MapEntry(:key, :value) in _map.entries)
      key: switch (value) {
        final String value => value,
        final num value => value,
        final bool value => value,
        _ => throw _Invalid('$path.$key is not a string, number or boolean'),
      },
  };

  List<_Object> objects(String key) => [
    for (final (index, item) in _field<List<Object?>>(key, 'a list').indexed)
      switch (item) {
        final Map<String, Object?> map => _Object(map, '$path.$key[$index]'),
        _ => throw _Invalid('$path.$key[$index] is not an object'),
      },
  ];
}
