import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:holyquran/data/models/catalogue_json.dart';
import 'package:holyquran/data/repositories/catalogue_repository.dart';
import 'package:holyquran/domain/models/catalogue.dart';
import 'package:holyquran/utils/result.dart';

const _hash = 'ab';

/// A lowercase hex SHA-256 made of [digit], for synthetic entries.
String syntheticHash([String digit = _hash]) => (digit * 64).substring(0, 64);

/// The JSON of a valid synthetic catalogue (docs/PACK_CATALOGUE.md) whose
/// URLs are under [base]: a text pack, the first-use tafsir and two
/// recitation packs, and two recitations, the second of them without a
/// complete rights record. Every text in it is obviously synthetic.
Map<String, Object?> syntheticCatalogueJson({
  String base = 'https://example.invalid/synthetic/',
  int tafsirVersion = 2,
}) {
  Map<String, Object?> file(String id, String name, int bytes) => {
    'name': name,
    'url': '$base$id/$name',
    'bytes': bytes,
    'sha256': syntheticHash(),
  };
  Map<String, Object?> pack(
    String id,
    String kind,
    int version,
    String fileName, {
    String? role,
  }) => {
    'id': id,
    'kind': kind,
    'version': version,
    'title': 'Synthetic $kind title',
    'manifest': {
      'url': '$base$id/manifest.json',
      'bytes': 100,
      'sha256': syntheticHash('cd'),
    },
    'signature': '$base$id/manifest.json.sig',
    'files': [file(id, fileName, 1000)],
    'source': 'Synthetic source summary',
    'changes': 'Synthetic change summary',
    'role': role,
  };
  Map<String, Object?> recitation(
    String id,
    String packId, {
    required bool rightsComplete,
  }) => {
    'id': id,
    'reciter': 'Synthetic reciter $id',
    'riwaya': 'hafs',
    'style': 'Synthetic style',
    'unit': 'ayah',
    'qualities': [64, 128],
    'pack': packId,
    'rights_complete': rightsComplete,
    'word_timing': false,
  };
  return {
    'format': 'holyquran-catalogue',
    'format_version': 1,
    'date': '2026-10-12',
    'packs': [
      pack('synthetic-text', 'text', 1, 'text.sqlite'),
      pack(
        'synthetic-tafsir',
        'tafsir',
        tafsirVersion,
        'tafsir.sqlite',
        role: 'first-use-tafsir',
      ),
      pack('synthetic-recitation', 'recitation', 1, 'recitation.sqlite'),
      pack('synthetic-unlisted', 'recitation', 1, 'recitation.sqlite'),
    ],
    'recitations': [
      recitation(
        'synthetic-listed',
        'synthetic-recitation',
        rightsComplete: true,
      ),
      recitation(
        'synthetic-rights-pending',
        'synthetic-unlisted',
        rightsComplete: false,
      ),
    ],
  };
}

/// The exact bytes of [json], as a server would send them.
Uint8List catalogueBytes(Map<String, Object?> json) =>
    utf8.encode(jsonEncode(json));

/// [syntheticCatalogueJson] parsed. Throws if it does not parse.
Catalogue syntheticCatalogue({int tafsirVersion = 2}) => switch (parseCatalogue(
  catalogueBytes(syntheticCatalogueJson(tafsirVersion: tafsirVersion)),
)) {
  Ok(:final value) => value,
  Failure(:final error) => throw StateError('$error'),
};

/// A [CatalogueRepository] in memory, for view-model tests. A test sets
/// [catalogue], which notifies listeners, and [refreshes], the answer of
/// [refresh]; [refreshCount] counts the calls.
final class FakeCatalogueRepository extends ChangeNotifier
    implements CatalogueRepository {
  FakeCatalogueRepository([this._catalogue]);

  Catalogue? _catalogue;

  /// Answers [refresh]; by default the catalogue is unreachable.
  Result<Catalogue> Function() refreshes = () => Failure(
    CatalogueUnreachable(Uri.parse('https://example.invalid/'), 'offline'),
  );

  int refreshCount = 0;

  @override
  Catalogue? get catalogue => _catalogue;

  set catalogue(Catalogue? value) {
    _catalogue = value;
    notifyListeners();
  }

  @override
  Future<Result<Catalogue>> refresh() async {
    refreshCount++;
    final result = refreshes();
    if (result case Ok(:final value)) catalogue = value;
    return result;
  }
}
