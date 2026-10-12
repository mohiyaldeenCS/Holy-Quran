import 'dart:convert';

import '../../domain/models/edition_map.dart';
import '../../domain/models/pack_failure.dart';
import '../../domain/models/pack_manifest.dart';
import '../../domain/models/quran_address.dart';
import '../../domain/models/search_form.dart';
import '../../utils/result.dart';

/// The pack format versions this app reads (docs/CONTENT_PACKS.md).
const supportedPackFormatVersions = {1, 2};

/// The newest of [supportedPackFormatVersions].
const supportedPackFormatVersion = 2;

/// The one data file of a text pack.
const textPackFileName = 'text.sqlite';

/// The one data file of a tafsir pack.
const tafsirPackFileName = 'tafsir.sqlite';

/// The one data file of a recitation pack.
const recitationPackFileName = 'recitation.sqlite';

/// What the format says of each kind: its one data file, the first format
/// version that has it, and the source roles its manifest may name, the
/// first of them required.
const _kinds = {
  PackKind.text: (
    file: textPackFileName,
    since: 1,
    roles: [SourceRole.text, SourceRole.editionMap, SourceRole.searchForms],
  ),
  PackKind.tafsir: (
    file: tafsirPackFileName,
    since: 2,
    roles: [SourceRole.tafsir],
  ),
  PackKind.recitation: (
    file: recitationPackFileName,
    since: 2,
    roles: [SourceRole.recitation],
  ),
};

const _roleNames = {
  'text': SourceRole.text,
  'edition_map': SourceRole.editionMap,
  'search_forms': SourceRole.searchForms,
  'tafsir': SourceRole.tafsir,
  'recitation': SourceRole.recitation,
};

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
      when !supportedPackFormatVersions.contains(version)) {
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
  final formatVersion = json.integer('format_version');
  final kind = switch (json.string('kind')) {
    'text' => PackKind.text,
    'tafsir' => PackKind.tafsir,
    'recitation' => PackKind.recitation,
    _ => throw const _Invalid('kind is not a known kind'),
  };
  final (:file, :since, :roles) = _kinds[kind]!;
  if (formatVersion < since) {
    throw _Invalid(
      'kind ${kind.name} is not a kind of format version $formatVersion',
    );
  }
  final isText = kind == PackKind.text;
  json.expectKeys({
    'format',
    'format_version',
    'id',
    'kind',
    'version',
    'changelog',
    'riwaya',
    'sources',
    'files',
    'counts',
    'reviews',
    if (isText) ...{'edition', 'font', 'surah_sha256'},
  });
  final riwaya = json.nullableString('riwaya');
  if (riwaya == null) throw _Invalid('riwaya of a ${kind.name} pack is null');
  if (!QuranAddress.riwayaPattern.hasMatch(riwaya)) {
    throw _Invalid(
      'riwaya is not of the form ${QuranAddress.riwayaPattern.pattern}',
    );
  }
  final counts = switch (kind) {
    PackKind.text => _counts(json.object('counts'), formatVersion),
    PackKind.tafsir => _tafsirCounts(json.object('counts')),
    PackKind.recitation => _recitationCounts(json.object('counts')),
  };
  final files = [for (final file in json.objects('files')) _file(file)];
  if (files.length != 1 || files.single.name != file) {
    throw _Invalid('files of a ${kind.name} pack is not exactly $file');
  }
  final sources = [
    for (final source in json.objects('sources')) _source(source),
  ];
  if (sources.isEmpty) throw const _Invalid('sources is empty');
  for (final source in sources) {
    if (!roles.contains(source.role)) {
      throw _Invalid(
        'sources of a ${kind.name} pack name the role ${source.role.name}',
      );
    }
  }
  if (!sources.any((source) => source.role == roles.first)) {
    throw _Invalid(
      'sources of a ${kind.name} pack has no ${roles.first.name} source',
    );
  }
  if (counts case PackCounts(:final searchForms)
      when searchForms.isEmpty ==
          sources.any((source) => source.role == SourceRole.searchForms)) {
    throw const _Invalid(
      'sources names a search_forms source exactly when counts.search_forms '
      'should list none',
    );
  }
  return PackManifest(
    formatVersion: formatVersion,
    id: json.string('id'),
    kind: kind,
    version: json.positive('version'),
    changelog: [
      for (final change in json.objects('changelog')) _change(change),
    ],
    riwaya: riwaya,
    edition: isText ? json.string('edition') : null,
    font: isText ? _font(json.object('font')) : null,
    sources: sources,
    files: files,
    surahSha256: switch (counts) {
      PackCounts(:final surahs) => _surahSha256(
        json.object('surah_sha256'),
        surahs,
      ),
      _ => null,
    },
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
    role:
        _roleNames[json.string('role')] ??
        (throw _Invalid('${json.path}.role is not a known role')),
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
    options: _options(json.nullableObject('options')),
    licence: _licence(json.object('licence')),
  );
}

/// Null when the source offers no choices; an empty object or an empty
/// option name is refused, so that "no choices" has one spelling.
Map<String, Object>? _options(_Object? json) {
  if (json == null) return null;
  final options = json.scalars();
  if (options.isEmpty) throw _Invalid('${json.path} is empty; use null');
  if (options.containsKey('')) {
    throw _Invalid('${json.path} has an empty option name');
  }
  return options;
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

PackCounts _counts(_Object json, int formatVersion) {
  json.expectKeys({
    'surahs',
    'ayat',
    'words',
    'marks',
    'divisions',
    'sajdas',
    if (formatVersion >= 2) 'search_forms',
  });
  final divisions = json.object('divisions')
    ..expectKeys({for (final division in Division.values) division.name});
  final words = json.count('words');
  return PackCounts(
    surahs: json.count('surahs'),
    ayat: json.count('ayat'),
    words: words,
    marks: json.count('marks'),
    divisions: {
      for (final division in Division.values)
        division: divisions.count(division.name),
    },
    sajdas: json.count('sajdas'),
    searchForms: formatVersion >= 2
        ? _searchFormCounts(json.object('search_forms'), words)
        : const {},
  );
}

/// One form per word for each kind: every count equals [words].
Map<String, int> _searchFormCounts(_Object json, int words) {
  for (final kind in json.keys) {
    if (!SearchForm.kindPattern.hasMatch(kind)) {
      throw _Invalid(
        '${json.path} has the kind $kind, not of the form '
        '${SearchForm.kindPattern.pattern}',
      );
    }
    if (json.count(kind) != words) {
      throw _Invalid('${json.path}.$kind is not counts.words');
    }
  }
  return {for (final kind in json.keys) kind: words};
}

TafsirCounts _tafsirCounts(_Object json) {
  json.expectKeys(const {'passages'});
  return TafsirCounts(passages: json.positive('passages'));
}

RecitationCounts _recitationCounts(_Object json) {
  json.expectKeys(const {'files'});
  return RecitationCounts(files: json.positive('files'));
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

  Iterable<String> get keys => _map.keys;

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
