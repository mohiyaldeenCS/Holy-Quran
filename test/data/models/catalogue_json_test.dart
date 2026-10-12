import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/data/models/catalogue_json.dart';
import 'package:holyquran/domain/models/catalogue.dart';
import 'package:holyquran/domain/models/catalogue_entry.dart';
import 'package:holyquran/domain/models/pack_manifest.dart';
import 'package:holyquran/domain/models/recitation.dart';
import 'package:holyquran/utils/result.dart';

import '../../../testing/fakes/fake_catalogue_repository.dart';

Result<Catalogue> _parse(Map<String, Object?> json) =>
    parseCatalogue(catalogueBytes(json));

/// The reason [json] is rejected for.
String _rejected(Map<String, Object?> json) => switch (_parse(json)) {
  Failure(error: CatalogueRejected(:final reason)) => reason,
  final other => fail('not rejected: $other'),
};

Map<String, Object?> _pack(Map<String, Object?> json, [int index = 0]) =>
    (json['packs']! as List<Object?>)[index]! as Map<String, Object?>;

Map<String, Object?> _recitation(Map<String, Object?> json, [int index = 0]) =>
    (json['recitations']! as List<Object?>)[index]! as Map<String, Object?>;

void main() {
  test('reads every field of a valid catalogue', () {
    final catalogue = switch (_parse(syntheticCatalogueJson())) {
      Ok(:final value) => value,
      Failure(:final error) => fail('$error'),
    };
    expect(catalogue.date, '2026-10-12');
    expect(
      [for (final pack in catalogue.packs) pack.id],
      [
        'synthetic-text',
        'synthetic-tafsir',
        'synthetic-recitation',
        'synthetic-unlisted',
      ],
    );
    final tafsir = catalogue.packs[1];
    expect(tafsir.kind, PackKind.tafsir);
    expect(tafsir.version, 2);
    expect(tafsir.title, 'Synthetic tafsir title');
    expect(
      tafsir.manifest.url,
      Uri.parse(
        'https://example.invalid/synthetic/synthetic-tafsir/manifest.json',
      ),
    );
    expect(tafsir.manifest.bytes, 100);
    expect(tafsir.manifest.sha256, syntheticHash('cd'));
    expect(
      tafsir.signature,
      Uri.parse(
        'https://example.invalid/synthetic/synthetic-tafsir/manifest.json.sig',
      ),
    );
    expect(tafsir.files.keys, ['tafsir.sqlite']);
    expect(tafsir.files['tafsir.sqlite']!.bytes, 1000);
    expect(tafsir.bytes, 1000);
    expect(tafsir.source, 'Synthetic source summary');
    expect(tafsir.changes, 'Synthetic change summary');
    expect(tafsir.role, CatalogueRole.firstUseTafsir);
    expect(catalogue.firstUseTafsir, same(tafsir));
    expect(catalogue.packs.first.role, isNull);

    final [listed, pending] = catalogue.recitations;
    expect(listed.id, 'synthetic-listed');
    expect(listed.recitation.reciter, 'Synthetic reciter synthetic-listed');
    expect(listed.recitation.riwaya, 'hafs');
    expect(listed.recitation.style, 'Synthetic style');
    expect(listed.recitation.unit, RecitationUnit.ayah);
    expect(listed.recitation.rightsComplete, isTrue);
    expect(listed.recitation.hasWordTiming, isFalse);
    expect(listed.qualities, [64, 128]);
    expect(listed.packId, 'synthetic-recitation');
    expect(pending.recitation.rightsComplete, isFalse);
    expect(catalogue.listedRecitations, [listed]);
  });

  test('reads a null signature, a surah unit and word timing', () {
    final json = syntheticCatalogueJson();
    _pack(json)['signature'] = null;
    _recitation(json)
      ..['unit'] = 'surah'
      ..['word_timing'] = true;
    final catalogue = (_parse(json) as Ok<Catalogue>).value;
    expect(catalogue.packs.first.signature, isNull);
    expect(catalogue.recitations.first.recitation.unit, RecitationUnit.surah);
    expect(catalogue.recitations.first.recitation.hasWordTiming, isTrue);
  });

  test('reads an empty catalogue', () {
    final json = syntheticCatalogueJson()
      ..['packs'] = <Object?>[]
      ..['recitations'] = <Object?>[];
    final catalogue = (_parse(json) as Ok<Catalogue>).value;
    expect(catalogue.packs, isEmpty);
    expect(catalogue.recitations, isEmpty);
  });

  test('refuses what is not a catalogue', () {
    expect(
      parseCatalogue([
        0xEF,
        0xBB,
        0xBF,
        ...catalogueBytes(syntheticCatalogueJson()),
      ]),
      isA<Failure<Catalogue>>().having(
        (f) => (f.error as CatalogueRejected).reason,
        'reason',
        contains('byte order mark'),
      ),
    );
    for (final bytes in [
      utf8.encode('not json'),
      [0xFF, 0xFE],
      utf8.encode('[]'),
    ]) {
      expect(
        parseCatalogue(bytes),
        isA<Failure<Catalogue>>().having(
          (f) => f.error,
          'error',
          isA<CatalogueRejected>(),
        ),
      );
    }
    expect(
      _rejected(syntheticCatalogueJson()..['format'] = 'holyquran-pack'),
      contains('format'),
    );
  });

  test('a format version other than 1 is unsupported', () {
    for (final (version, reported) in [
      (2, 2),
      (0, 0),
      ('1', null),
      (null, null),
    ]) {
      expect(
        _parse(syntheticCatalogueJson()..['format_version'] = version),
        isA<Failure<Catalogue>>().having(
          (f) => (f.error as CatalogueUnsupported).version,
          'version',
          reported,
        ),
      );
    }
  });

  test('refuses an unknown or a missing field at every level', () {
    final top = syntheticCatalogueJson()..['extra'] = 1;
    expect(_rejected(top), 'catalogue has unknown field extra');
    final pack = syntheticCatalogueJson();
    _pack(pack)['size'] = 1;
    expect(_rejected(pack), 'catalogue.packs[0] has unknown field size');
    final manifest = syntheticCatalogueJson();
    (_pack(manifest)['manifest']! as Map<String, Object?>)['extra'] = 1;
    expect(
      _rejected(manifest),
      'catalogue.packs[0].manifest has unknown field extra',
    );
    final file = syntheticCatalogueJson();
    ((_pack(file)['files']! as List<Object?>).first! as Map<String, Object?>)
        .remove('sha256');
    expect(_rejected(file), 'catalogue.packs[0].files[0] lacks field sha256');
    final recitation = syntheticCatalogueJson();
    _recitation(recitation).remove('word_timing');
    expect(
      _rejected(recitation),
      'catalogue.recitations[0] lacks field word_timing',
    );
    expect(
      _rejected(syntheticCatalogueJson()..remove('date')),
      'catalogue lacks field date',
    );
  });

  test('refuses a value that breaks the format', () {
    final cases = <String, void Function(Map<String, Object?> json)>{
      'a date that is no date': (json) => json['date'] = '2026-02-30',
      'a date in another form': (json) => json['date'] = '12/10/2026',
      'packs that are no list': (json) => json['packs'] = {},
      'a pack that is no object': (json) => json['packs'] = [1],
      'an unknown kind': (json) => _pack(json)['kind'] = 'pages',
      'a version that is no integer': (json) => _pack(json)['version'] = '1',
      'version 0': (json) => _pack(json)['version'] = 0,
      'a pack id in upper case': (json) => _pack(json)['id'] = 'Synthetic',
      'an empty title': (json) => _pack(json)['title'] = '',
      'an empty source': (json) => _pack(json)['source'] = '',
      'an empty change summary': (json) => _pack(json)['changes'] = '',
      'an unknown role': (json) => _pack(json)['role'] = 'default',
      'a role on a text pack': (json) =>
          _pack(json)['role'] = 'first-use-tafsir',
      'an upper-case hash': (json) =>
          (_pack(json)['manifest']! as Map<String, Object?>)['sha256'] =
              syntheticHash('AB'),
      'a manifest of 0 bytes': (json) =>
          (_pack(json)['manifest']! as Map<String, Object?>)['bytes'] = 0,
      'a relative URL': (json) =>
          (_pack(json)['manifest']! as Map<String, Object?>)['url'] =
              'synthetic/manifest.json',
      'a URL with a user': (json) =>
          _pack(json)['signature'] = 'https://user@example.invalid/x.sig',
      'a URL with a fragment': (json) =>
          _pack(json)['signature'] = 'https://example.invalid/x.sig#part',
      'a signature that is no string': (json) => _pack(json)['signature'] = 1,
      'no files': (json) => _pack(json)['files'] = <Object?>[],
      'a file name with a slash': (json) =>
          ((_pack(json)['files']! as List<Object?>).first!
                  as Map<String, Object?>)['name'] =
              'a/text.sqlite',
      'a file listed twice': (json) {
        final files = _pack(json)['files']! as List<Object?>;
        files.add(files.first);
      },
      'a pack listed twice': (json) =>
          (json['packs']! as List<Object?>).add(_pack(json)),
      'two roles': (json) => _pack(json)
        ..['kind'] = 'tafsir'
        ..['role'] = 'first-use-tafsir',
      'an unknown unit': (json) => _recitation(json)['unit'] = 'page',
      'a riwaya in another form': (json) =>
          _recitation(json)['riwaya'] = 'Hafs',
      'qualities that do not rise': (json) =>
          _recitation(json)['qualities'] = [128, 64],
      'no quality': (json) => _recitation(json)['qualities'] = <Object?>[],
      'a quality that is no integer': (json) =>
          _recitation(json)['qualities'] = [64.5],
      'rights that are no boolean': (json) =>
          _recitation(json)['rights_complete'] = 'yes',
      'a recitation of an unknown pack': (json) =>
          _recitation(json)['pack'] = 'synthetic-none',
      'a recitation of a text pack': (json) =>
          _recitation(json)['pack'] = 'synthetic-text',
      'two recitations of one pack': (json) =>
          _recitation(json, 1)['pack'] = 'synthetic-recitation',
      'an empty reciter': (json) => _recitation(json)['reciter'] = '',
    };
    for (final MapEntry(key: name, value: edit) in cases.entries) {
      final json = syntheticCatalogueJson();
      edit(json);
      expect(
        _parse(json),
        isA<Failure<Catalogue>>().having(
          (f) => f.error,
          'error',
          isA<CatalogueRejected>(),
        ),
        reason: name,
      );
    }
  });
}
