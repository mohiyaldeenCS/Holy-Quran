import 'dart:convert';

import '../../domain/models/catalogue.dart';
import '../../domain/models/catalogue_entry.dart';
import '../../domain/models/install_job.dart';
import '../../domain/models/pack_manifest.dart';
import '../../domain/models/recitation.dart';
import '../../utils/result.dart';

/// The catalogue format version this app reads (docs/PACK_CATALOGUE.md).
const catalogueFormatVersion = 1;

/// Parses the exact bytes of `catalogue.json` (docs/PACK_CATALOGUE.md):
/// UTF-8 without a byte order mark, every field present, no unknown field.
Result<Catalogue> parseCatalogue(List<int> bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF) {
    return const Failure(CatalogueRejected('begins with a byte order mark'));
  }
  final Object? json;
  try {
    json = jsonDecode(utf8.decode(bytes));
  } on FormatException catch (e) {
    return Failure(CatalogueRejected('not UTF-8 JSON: ${e.message}'));
  }
  if (json is! Map<String, Object?>) {
    return const Failure(CatalogueRejected('not a JSON object'));
  }
  if (json['format'] != 'holyquran-catalogue') {
    return const Failure(
      CatalogueRejected('format is not holyquran-catalogue'),
    );
  }
  switch (json['format_version']) {
    case catalogueFormatVersion:
      break;
    case final int version:
      return Failure(CatalogueUnsupported(version));
    default:
      return const Failure(CatalogueUnsupported(null));
  }
  try {
    return Ok(_catalogue(_Object(json, 'catalogue')));
  } on _Invalid catch (e) {
    return Failure(CatalogueRejected(e.reason));
  } on ArgumentError catch (e) {
    return Failure(
      CatalogueRejected('${e.name} ${e.message}: ${e.invalidValue}'),
    );
  }
}

const _kinds = {
  'text': PackKind.text,
  'tafsir': PackKind.tafsir,
  'recitation': PackKind.recitation,
};

const _units = {'ayah': RecitationUnit.ayah, 'surah': RecitationUnit.surah};

Catalogue _catalogue(_Object json) {
  json.expectKeys({'format', 'format_version', 'date', 'packs', 'recitations'});
  return Catalogue(
    date: json.date('date'),
    packs: [for (final pack in json.objects('packs')) _pack(pack)],
    recitations: [
      for (final recitation in json.objects('recitations'))
        _recitation(recitation),
    ],
  );
}

CatalogueEntry _pack(_Object json) {
  json.expectKeys({
    'id',
    'kind',
    'version',
    'title',
    'manifest',
    'signature',
    'files',
    'source',
    'changes',
    'role',
  });
  final manifest = json.object('manifest')
    ..expectKeys({'url', 'bytes', 'sha256'});
  final files = <String, RemoteFile>{};
  for (final file in json.objects('files')) {
    file.expectKeys({'name', 'url', 'bytes', 'sha256'});
    final name = file.string('name');
    if (files.containsKey(name)) {
      throw _Invalid('${json.path}.files lists $name twice');
    }
    files[name] = _remoteFile(file);
  }
  return CatalogueEntry(
    id: json.string('id'),
    kind:
        _kinds[json.string('kind')] ??
        (throw _Invalid('${json.path}.kind is not a known kind')),
    version: json.integer('version'),
    title: json.string('title'),
    manifest: _remoteFile(manifest),
    signature: json.nullableUrl('signature'),
    files: files,
    source: json.string('source'),
    changes: json.string('changes'),
    role: switch (json.nullableString('role')) {
      null => null,
      'first-use-tafsir' => CatalogueRole.firstUseTafsir,
      _ => throw _Invalid('${json.path}.role is not a known role'),
    },
  );
}

RemoteFile _remoteFile(_Object json) => RemoteFile(
  url: json.url('url'),
  sha256: json.hash('sha256'),
  bytes: json.positive('bytes'),
);

CatalogueRecitation _recitation(_Object json) {
  json.expectKeys({
    'id',
    'reciter',
    'riwaya',
    'style',
    'unit',
    'qualities',
    'pack',
    'rights_complete',
    'word_timing',
  });
  return CatalogueRecitation(
    recitation: Recitation(
      id: json.string('id'),
      reciter: json.string('reciter'),
      riwaya: json.string('riwaya'),
      style: json.string('style'),
      unit:
          _units[json.string('unit')] ??
          (throw _Invalid('${json.path}.unit is not ayah or surah')),
      hasWordTiming: json.boolean('word_timing'),
      rightsComplete: json.boolean('rights_complete'),
    ),
    qualities: json.integers('qualities'),
    packId: json.string('pack'),
  );
}

final class _Invalid implements Exception {
  const _Invalid(this.reason);

  final String reason;
}

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

  int positive(String key) {
    final value = integer(key);
    if (value < 1) throw _Invalid('$path.$key is not positive');
    return value;
  }

  List<int> integers(String key) => [
    for (final (index, item) in _field<List<Object?>>(key, 'a list').indexed)
      switch (item) {
        final int value => value,
        _ => throw _Invalid('$path.$key[$index] is not an integer'),
      },
  ];

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

  /// An absolute URL with a scheme and a host, and no user or fragment.
  Uri url(String key) {
    final url = Uri.tryParse(string(key));
    if (url == null ||
        !url.hasScheme ||
        url.host.isEmpty ||
        url.userInfo.isNotEmpty ||
        url.hasFragment) {
      throw _Invalid('$path.$key is not an absolute URL with a host');
    }
    return url;
  }

  Uri? nullableUrl(String key) => _map[key] == null ? null : url(key);

  _Object object(String key) =>
      _Object(_field<Map<String, Object?>>(key, 'an object'), '$path.$key');

  List<_Object> objects(String key) => [
    for (final (index, item) in _field<List<Object?>>(key, 'a list').indexed)
      switch (item) {
        final Map<String, Object?> map => _Object(map, '$path.$key[$index]'),
        _ => throw _Invalid('$path.$key[$index] is not an object'),
      },
  ];
}
