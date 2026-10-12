import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/data/models/pack_manifest_json.dart';
import 'package:holyquran/domain/models/edition_map.dart';
import 'package:holyquran/domain/models/pack_failure.dart';
import 'package:holyquran/domain/models/pack_manifest.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/utils/result.dart';

import '../../../testing/packs/synthetic_pack.dart';
import '../../../testing/packs/synthetic_recitation_pack.dart';
import '../../../testing/packs/synthetic_tafsir_pack.dart';

typedef Json = Map<String, Object?>;

void main() {
  late Directory root;
  late Json valid;
  late Json textV2;
  late Json tafsir;
  late Json recitation;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('pack_manifest_json_test');
    valid = (await buildSyntheticPack(root)).manifest;
    textV2 = (await buildSyntheticPack(
      root,
      formatVersion: 2,
      id: 'synthetic-text-v2',
    )).manifest;
    tafsir = (await buildSyntheticTafsirPack(root)).manifest;
    recitation = (await buildSyntheticRecitationPack(root)).manifest;
  });
  tearDownAll(() => root.delete(recursive: true));

  Json copy() => jsonDecode(jsonEncode(valid)) as Json;

  Result<PackManifest> parse(Object? json) =>
      parsePackManifest(utf8.encode(jsonEncode(json)), pack: 'p');

  Matcher fails(Matcher error) => isA<Failure<PackManifest>>().having(
    (failure) => failure.error,
    'error',
    error,
  );
  final unreadable = fails(
    isA<ManifestUnreadable>().having((f) => f.pack, 'pack', 'p'),
  );

  Matcher unreadableBecause(String reason) => fails(
    isA<ManifestUnreadable>().having((f) => f.reason, 'reason', reason),
  );

  Matcher unsupported(int? version) => fails(
    isA<UnsupportedPackFormat>().having(
      (f) => f.formatVersion,
      'formatVersion',
      version,
    ),
  );

  Json edited(void Function(Json json) edit) => copy()..apply(edit);

  test('reads every field of a valid manifest', () {
    final manifest = (parse(valid) as Ok<PackManifest>).value;
    final source = (valid['sources']! as List)[0] as Json;
    final file = (valid['files']! as List)[0] as Json;
    final font = valid['font']! as Json;
    expect(manifest.formatVersion, 1);
    expect(manifest.id, 'synthetic-text');
    expect(manifest.kind, PackKind.text);
    expect(manifest.version, 1);
    expect(manifest.changelog.single.version, 1);
    expect(manifest.changelog.single.date, '2026-01-01');
    expect(manifest.changelog.single.summary, 'Synthetic pack');
    expect(manifest.riwaya, 'hafs');
    expect(manifest.edition, 'synthetic-edition');
    expect(manifest.font.family, font['family']);
    expect(manifest.font.version, font['version']);
    expect(manifest.font.sha256, font['sha256']);
    expect(manifest.sources.map((s) => s.role), [
      SourceRole.text,
      SourceRole.editionMap,
    ]);
    expect(manifest.sources.map((s) => s.registryRow), [1, 4]);
    final first = manifest.sources.first;
    expect(first.name, source['name']);
    expect(first.publisher, source['publisher']);
    expect(first.url, source['url']);
    expect(first.version, source['version']);
    expect(first.fetchedOn, source['fetched_on']);
    expect(first.fileSha256, source['file_sha256']);
    expect(first.trustGrade, TrustGrade.a);
    expect(first.options, source['options']);
    expect(first.options, isNotEmpty);
    expect(manifest.sources[1].options, isNull);
    expect(first.licence.text, isNull);
    expect(first.licence.permissionRef, 'Synthetic permission 1');
    expect(first.licence.notice, isNull);
    expect(first.licence.allowsExport, isTrue);
    expect(manifest.files.single.name, textPackFileName);
    expect(manifest.files.single.sha256, file['sha256']);
    expect(manifest.files.single.bytes, file['bytes']);
    expect(manifest.surahSha256, {
      for (final MapEntry(:key, :value)
          in (valid['surah_sha256']! as Json).entries)
        int.parse(key): value,
    });
    expect(manifest.counts.surahs, 3);
    expect(manifest.counts.ayat, 8);
    expect(manifest.counts.words, (valid['counts']! as Json)['words']);
    expect(manifest.counts.marks, (valid['counts']! as Json)['marks']);
    expect(manifest.counts.marks, greaterThan(0));
    expect(manifest.counts.divisions, {
      Division.juz: 2,
      Division.hizb: 4,
      Division.rub: 8,
      Division.page: 4,
    });
    expect(manifest.counts.sajdas, 2);
    expect(manifest.reviews.single.reviewer, 'synthetic reviewer');
    expect(manifest.reviews.single.date, '2026-01-01');
    expect(manifest.reviews.single.scope, 'synthetic test data');
  });

  test('reads licence strings and other trust grades', () {
    final json = edited((json) {
      json.at(['sources', 0, 'licence'])
        ..['text'] = 'Synthetic licence'
        ..['permission_ref'] = 'Synthetic permission'
        ..['notice'] = 'Synthetic notice'
        ..['allows_export'] = false;
      json.at(['sources', 0])['trust_grade'] = 'B';
      json.at(['sources', 1])['trust_grade'] = 'C';
    });
    final manifest = (parse(json) as Ok<PackManifest>).value;
    final licence = manifest.sources.first.licence;
    expect(licence.text, 'Synthetic licence');
    expect(licence.permissionRef, 'Synthetic permission');
    expect(licence.notice, 'Synthetic notice');
    expect(licence.allowsExport, isFalse);
    expect(manifest.sources.map((s) => s.trustGrade), [
      TrustGrade.b,
      TrustGrade.c,
    ]);
  });

  group('the bytes', () {
    final bom = [0xEF, 0xBB, 0xBF];

    test('must not begin with a byte order mark', () {
      expect(
        parsePackManifest([
          ...bom,
          ...utf8.encode(jsonEncode(valid)),
        ], pack: 'p'),
        unreadableBecause('begins with a byte order mark'),
      );
    });

    test('must be strict UTF-8', () {
      final json = edited((json) => json['edition'] = 'synthetic-\u{E9}');
      expect(parse(json), isA<Ok<PackManifest>>());
      final bytes = utf8.encode(jsonEncode(json));
      final at = bytes.indexOf(0xC3);
      final malformed = [...bytes.take(at), 0xFF, ...bytes.skip(at + 2)];
      expect(parsePackManifest(malformed, pack: 'p'), unreadable);
    });

    test('must be one JSON object', () {
      expect(
        parsePackManifest(utf8.encode('{"format": '), pack: 'p'),
        unreadable,
      );
      expect(parse([valid]), unreadableBecause('not a JSON object'));
      expect(parse('holyquran-pack'), unreadable);
    });
  });

  group('format', () {
    test('must be holyquran-pack', () {
      for (final format in ['holyquran-pack2', 'HOLYQURAN-PACK', null]) {
        expect(
          parse(edited((json) => json['format'] = format)),
          unreadableBecause('format is not holyquran-pack'),
        );
      }
      expect(parse(edited((json) => json.remove('format'))), unreadable);
    });

    test('a version other than 1 and 2 is unsupported', () {
      for (final version in [0, 3, 100, -1]) {
        expect(
          parse(edited((json) => json['format_version'] = version)),
          unsupported(version),
        );
      }
    });

    test('a version that is not an integer is unsupported, with none', () {
      for (final version in [
        '1',
        1.5,
        true,
        null,
        <Object?>[1],
      ]) {
        expect(
          parse(edited((json) => json['format_version'] = version)),
          unsupported(null),
        );
      }
      expect(
        parse(edited((json) => json.remove('format_version'))),
        unsupported(null),
      );
    });

    test('an unsupported version wins over unknown fields', () {
      expect(
        parse(
          edited((json) {
            json['format_version'] = 3;
            json['new_field'] = 1;
            json.remove('reviews');
          }),
        ),
        unsupported(3),
      );
    });
  });

  // The names inside `options` are the source's own, so the walk stops at
  // `options`; its rules are tested on their own below.
  group('every field', () {
    final paths = <List<Object>>[];
    final objects = <List<Object>>[];

    setUpAll(() {
      void walk(Object? node, List<Object> at) {
        if (at.isNotEmpty && at.last == 'options') return;
        switch (node) {
          case final Json map:
            objects.add(at);
            for (final MapEntry(:key, :value) in map.entries) {
              paths.add([...at, key]);
              walk(value, [...at, key]);
            }
          case final List<Object?> list:
            for (final (index, item) in list.indexed) {
              walk(item, [...at, index]);
            }
        }
      }

      walk(valid, []);
      expect(paths, hasLength(greaterThan(60)));
    });

    Matcher expected(List<Object> path) =>
        path.length == 1 && path.single == 'format_version'
        ? unsupported(null)
        : unreadable;

    test('is required', () {
      for (final path in paths) {
        final json = copy();
        json.delete(path);
        expect(parse(json), expected(path), reason: path.join('.'));
      }
    });

    test('rejects a value of another type', () {
      for (final path in paths) {
        final json = copy();
        json.set(path, switch (json.get(path)) {
          Map() || List() => 'synthetic',
          _ => <Object?>[true],
        });
        expect(parse(json), expected(path), reason: path.join('.'));
      }
    });

    test('rejects null where null is not allowed', () {
      const nullable = {'text', 'permission_ref', 'notice'};
      for (final path in paths) {
        if (path.length == 4 &&
            path[2] == 'licence' &&
            nullable.contains(path.last)) {
          continue;
        }
        if (path.length == 3 && path.last == 'options') continue;
        final json = copy();
        json.set(path, null);
        expect(parse(json), expected(path), reason: path.join('.'));
      }
    });

    test('of an object may not be unknown', () {
      for (final at in objects) {
        final json = copy();
        json.at(at)['synthetic_extra'] = 1;
        expect(
          parse(json),
          fails(
            isA<ManifestUnreadable>().having(
              (f) => f.reason,
              'reason',
              endsWith('has unknown field synthetic_extra'),
            ),
          ),
          reason: at.join('.'),
        );
      }
    });
  });

  test('kind must be known', () {
    for (final kind in ['pages', 'Text', '']) {
      expect(
        parse(edited((json) => json['kind'] = kind)),
        unreadableBecause('kind is not a known kind'),
      );
    }
  });

  test('riwaya of a text pack is a name in the address form', () {
    expect(
      parse(edited((json) => json['riwaya'] = null)),
      unreadableBecause('riwaya of a text pack is null'),
    );
    for (final riwaya in ['Hafs', '', 'ha fs', '1hafs', 'hafs:1']) {
      expect(parse(edited((json) => json['riwaya'] = riwaya)), unreadable);
    }
    expect(
      parse(edited((json) => json['riwaya'] = 'warsh_2')),
      isA<Ok<PackManifest>>(),
    );
  });

  test('riwaya is accepted exactly when QuranAddress accepts it', () {
    for (final riwaya in ['hafs', 'warsh_2', 'q1', 'Hafs', '_hafs', 'ha-fs']) {
      expect(
        parse(edited((json) => json['riwaya'] = riwaya)) is Ok,
        QuranAddress.riwayaPattern.hasMatch(riwaya),
        reason: riwaya,
      );
    }
  });

  group('sources', () {
    test('must not be empty', () {
      expect(
        parse(edited((json) => json['sources'] = <Object?>[])),
        unreadableBecause('sources is empty'),
      );
    });

    test('have a known role', () {
      for (final role in ['Text', 'edition-map', 'editionMap', 'pages', '']) {
        expect(
          parse(edited((json) => json.at(['sources', 1])['role'] = role)),
          unreadableBecause('manifest.sources[1].role is not a known role'),
          reason: role,
        );
      }
    });

    test('of a text pack include a text source', () {
      expect(
        parse(
          edited((json) => json.at(['sources', 0])['role'] = 'edition_map'),
        ),
        unreadableBecause('sources of a text pack has no text source'),
      );
      expect(
        parse(
          edited((json) => (json['sources']! as List<Object?>).removeAt(1)),
        ),
        isA<Ok<PackManifest>>(),
      );
    });

    test('each have a licence text or a permission reference', () {
      final licence = ['sources', 1, 'licence'];
      expect(
        parse(edited((json) => json.at(licence)['permission_ref'] = null)),
        unreadableBecause(
          'manifest.sources[1].licence has neither text nor permission_ref',
        ),
      );
      final withText = parse(
        edited((json) {
          json.at(licence)
            ..['permission_ref'] = null
            ..['text'] = 'Synthetic licence';
        }),
      );
      expect(
        (withText as Ok<PackManifest>).value.sources[1].licence.text,
        'Synthetic licence',
      );
    });
  });

  group('options', () {
    final options = ['sources', 0, 'options'];

    test('may be null, or names with scalar values', () {
      final withNull = parse(edited((json) => json.set(options, null)));
      expect((withNull as Ok<PackManifest>).value.sources[0].options, isNull);
      final given = <String, Object?>{
        'Synthetic Name': 'synthetic',
        'synthetic empty value': '',
        'synthetic-count': 0,
        'synthetic ratio': -0.25,
        'synthetic flag': false,
      };
      final parsed = parse(edited((json) => json.set(options, given)));
      expect((parsed as Ok<PackManifest>).value.sources[0].options, given);
    });

    test('refuse an empty object: no choices is null', () {
      expect(
        parse(edited((json) => json.set(options, <String, Object?>{}))),
        unreadableBecause('manifest.sources[0].options is empty; use null'),
      );
      expect(
        parse(
          edited(
            (json) => json.at(['sources', 1])['options'] = <String, Object?>{},
          ),
        ),
        unreadableBecause('manifest.sources[1].options is empty; use null'),
      );
    });

    test('refuse an empty option name', () {
      expect(
        parse(edited((json) => json.at(options)[''] = 'synthetic')),
        unreadableBecause(
          'manifest.sources[0].options has an empty option name',
        ),
      );
    });

    test('refuse a value that is an object, a list or null', () {
      for (final value in [
        <String, Object?>{'synthetic': 1},
        <Object?>['synthetic'],
        <Object?>[],
        null,
      ]) {
        expect(
          parse(edited((json) => json.at(options)['synthetic_option'] = value)),
          unreadableBecause(
            'manifest.sources[0].options.synthetic_option is not a string, '
            'number or boolean',
          ),
          reason: '$value',
        );
      }
    });

    test('must be an object or null', () {
      for (final value in ['synthetic', 1, true, <Object?>[]]) {
        expect(
          parse(edited((json) => json.set(options, value))),
          unreadableBecause(
            'manifest.sources[0].options is not an object or null',
          ),
          reason: '$value',
        );
      }
    });

    test('are required in every source', () {
      expect(
        parse(edited((json) => json.at(['sources', 1]).remove('options'))),
        unreadableBecause('manifest.sources[1] lacks field options'),
      );
    });
  });

  test('counts.marks is a required count', () {
    expect(
      parse(edited((json) => json.at(['counts']).remove('marks'))),
      unreadableBecause('manifest.counts lacks field marks'),
    );
    for (final value in [-1, 1.0, '1', null]) {
      expect(
        parse(edited((json) => json.at(['counts'])['marks'] = value)),
        unreadable,
        reason: '$value',
      );
    }
    final none = parse(edited((json) => json.at(['counts'])['marks'] = 0));
    expect((none as Ok<PackManifest>).value.counts.marks, 0);
  });

  test('trust grades are A, B or C', () {
    for (final grade in ['a', 'D', 'A+', '']) {
      expect(
        parse(edited((json) => json.at(['sources', 1])['trust_grade'] = grade)),
        unreadableBecause('manifest.sources[1].trust_grade is not A, B or C'),
      );
    }
  });

  test('every hash is lowercase hex SHA-256', () {
    final hashes = [
      ['font', 'sha256'],
      ['sources', 0, 'file_sha256'],
      ['sources', 1, 'file_sha256'],
      ['files', 0, 'sha256'],
      ['surah_sha256', '1'],
      ['surah_sha256', '3'],
    ];
    for (final path in hashes) {
      final hash = copy().get(path)! as String;
      for (final wrong in [
        hash.toUpperCase(),
        hash.substring(1),
        '${hash}0',
        'g${hash.substring(1)}',
        ' ${hash.substring(1)}',
        '',
      ]) {
        final json = copy();
        json.set(path, wrong);
        expect(parse(json), unreadable, reason: '${path.join('.')} = $wrong');
      }
    }
  });

  test('every date is a calendar date written YYYY-MM-DD', () {
    final dates = [
      ['changelog', 0, 'date'],
      ['sources', 0, 'fetched_on'],
      ['reviews', 0, 'date'],
    ];
    for (final path in dates) {
      for (final wrong in [
        '2026-1-01',
        '2026-01-1',
        '26-01-01',
        '2026/01/01',
        '2026-02-30',
        '2026-13-01',
        '2026-00-10',
        '2026-01-01T00:00',
        '\u{662}\u{660}\u{662}\u{666}-01-01',
      ]) {
        final json = copy();
        json.set(path, wrong);
        expect(parse(json), unreadable, reason: '${path.join('.')} = $wrong');
      }
      final json = copy();
      json.set(path, '2024-02-29');
      expect(parse(json), isA<Ok<PackManifest>>());
    }
  });

  test('a file name is bare', () {
    for (final name in [
      '../text.sqlite',
      'dir/text.sqlite',
      r'dir\text.sqlite',
      '/text.sqlite',
      '..',
      '.',
      '',
      'text..sqlite',
    ]) {
      expect(
        parse(edited((json) => json.at(['files', 0])['name'] = name)),
        unreadableBecause('manifest.files[0].name is not a bare file name'),
        reason: name,
      );
    }
  });

  test('a text pack lists exactly one file, text.sqlite', () {
    const reason = 'files of a text pack is not exactly $textPackFileName';
    expect(
      parse(edited((json) => json.at(['files', 0])['name'] = 'other.sqlite')),
      unreadableBecause(reason),
    );
    expect(
      parse(
        edited((json) {
          final files = json['files']! as List<Object?>;
          files.add(jsonDecode(jsonEncode(files[0])));
        }),
      ),
      unreadableBecause(reason),
    );
    expect(
      parse(edited((json) => json['files'] = <Object?>[])),
      unreadableBecause(reason),
    );
  });

  test('surah_sha256 has exactly the keys 1 to counts.surahs', () {
    final hash = (valid['surah_sha256']! as Json)['1'];
    for (final edit in <void Function(Json)>[
      (json) => json.at(['surah_sha256']).remove('3'),
      (json) => json.at(['surah_sha256'])['4'] = hash,
      (json) => json.at(['surah_sha256'])['01'] = json
          .at(['surah_sha256'])
          .remove('1'),
      (json) => json.at(['surah_sha256'])['0'] = hash,
      (json) => json.at(['counts'])['surahs'] = 2,
      (json) => json.at(['counts'])['surahs'] = 4,
    ]) {
      expect(parse(edited(edit)), unreadable);
    }
    expect(
      parse(
        edited((json) {
          json['surah_sha256'] = <String, Object?>{};
          json.at(['counts'])['surahs'] = 0;
        }),
      ),
      isA<Ok<PackManifest>>(),
    );
  });

  test('counts are not negative and versions are positive', () {
    for (final path in [
      ['counts', 'ayat'],
      ['counts', 'words'],
      ['counts', 'marks'],
      ['counts', 'sajdas'],
      ['counts', 'divisions', 'page'],
      ['files', 0, 'bytes'],
    ]) {
      final json = copy();
      json.set(path, -1);
      expect(parse(json), unreadable, reason: path.join('.'));
    }
    for (final path in [
      ['version'],
      ['changelog', 0, 'version'],
      ['sources', 0, 'registry_row'],
    ]) {
      final json = copy();
      json.set(path, 0);
      expect(parse(json), unreadable, reason: path.join('.'));
    }
    expect(
      parse(edited((json) => json.at(['counts', 'divisions'])['juz'] = 0)),
      isA<Ok<PackManifest>>(),
    );
  });

  test('an integer written with a fraction is not an integer', () {
    expect(parse(edited((json) => json['version'] = 1.0)), unreadable);
    expect(
      parse(edited((json) => json.at(['counts'])['ayat'] = 8.0)),
      unreadable,
    );
  });

  test('the changelog and reviews may be empty', () {
    expect(
      parse(
        edited((json) {
          json['changelog'] = <Object?>[];
          json['reviews'] = <Object?>[];
        }),
      ),
      isA<Ok<PackManifest>>(),
    );
  });

  test('an item of a list must be an object', () {
    for (final key in ['changelog', 'sources', 'files', 'reviews']) {
      expect(
        parse(edited((json) => (json[key]! as List<Object?>).add('synthetic'))),
        unreadable,
        reason: key,
      );
    }
  });

  group('format version 2', () {
    Json from(Json json, void Function(Json json) edit) =>
        (jsonDecode(jsonEncode(json)) as Json)..apply(edit);

    test('reads a text pack with its search form kinds and source', () {
      final manifest = (parse(textV2) as Ok<PackManifest>).value;
      expect(manifest.formatVersion, 2);
      expect(manifest.kind, PackKind.text);
      final words = (textV2['counts']! as Json)['words'];
      expect(manifest.counts.searchForms, {
        for (final kind in defaultSyntheticSearchFormKinds) kind: words,
      });
      expect(manifest.sources.map((s) => s.role), [
        SourceRole.text,
        SourceRole.editionMap,
        SourceRole.searchForms,
      ]);
    });

    test('reads a text pack that provides no search forms', () async {
      final none = (await buildSyntheticPack(
        Directory('${root.path}/none'),
        formatVersion: 2,
        searchFormKinds: const [],
      )).manifest;
      final manifest = (parse(none) as Ok<PackManifest>).value;
      expect(manifest.counts.searchForms, isEmpty);
      expect(manifest.sources.map((s) => s.role), [
        SourceRole.text,
        SourceRole.editionMap,
      ]);
    });

    test('a format 1 text pack has no search forms and may not list them', () {
      expect(
        (parse(valid) as Ok<PackManifest>).value.counts.searchForms,
        isEmpty,
      );
      expect(
        parse(
          edited(
            (json) =>
                (json['counts']! as Json)['search_forms'] = <String, int>{},
          ),
        ),
        unreadableBecause('manifest.counts has unknown field search_forms'),
      );
    });

    test('a text pack lists its search form kinds in counts', () {
      expect(
        parse(
          from(
            textV2,
            (json) => (json['counts']! as Json).remove('search_forms'),
          ),
        ),
        unreadableBecause('manifest.counts lacks field search_forms'),
      );
      for (final kind in ['Synthetic', 'a b', '', 'a--b']) {
        expect(
          parse(
            from(textV2, (json) {
              final forms = json.at(['counts', 'search_forms']);
              forms[kind] = forms.values.first;
            }),
          ),
          unreadable,
          reason: kind,
        );
      }
    });

    test('a text pack counts one form per word of each kind', () {
      expect(
        parse(
          from(textV2, (json) {
            final forms = json.at(['counts', 'search_forms']);
            final kind = forms.keys.first;
            forms[kind] = (forms[kind]! as int) - 1;
          }),
        ),
        unreadableBecause(
          'manifest.counts.search_forms.'
          '${defaultSyntheticSearchFormKinds.first} is not counts.words',
        ),
      );
    });

    test(
      'a text pack names a search_forms source exactly when it has forms',
      () {
        expect(
          parse(
            from(
              textV2,
              (json) => (json['sources']! as List<Object?>).removeLast(),
            ),
          ),
          unreadable,
        );
        expect(
          parse(
            from(
              textV2,
              (json) => json.at(['counts'])['search_forms'] = <String, int>{},
            ),
          ),
          unreadable,
        );
      },
    );

    test('reads a tafsir pack', () {
      final manifest = (parse(tafsir) as Ok<PackManifest>).value;
      expect(manifest.kind, PackKind.tafsir);
      expect(manifest.formatVersion, 2);
      expect(manifest.riwaya, 'hafs');
      expect(manifest.files.single.name, tafsirPackFileName);
      expect(manifest.sources.single.role, SourceRole.tafsir);
      expect(
        (manifest.kindCounts as TafsirCounts).passages,
        defaultSyntheticPassages.length,
      );
      expect(() => manifest.font, throwsStateError);
    });

    test('reads a recitation pack', () {
      final manifest = (parse(recitation) as Ok<PackManifest>).value;
      expect(manifest.kind, PackKind.recitation);
      expect(manifest.riwaya, 'hafs');
      expect(manifest.files.single.name, recitationPackFileName);
      expect(manifest.sources.single.role, SourceRole.recitation);
      expect(
        (manifest.kindCounts as RecitationCounts).files,
        (recitation['counts']! as Json)['files'],
      );
    });

    group('a tafsir or recitation pack', () {
      final cases = {
        'tafsir': (() => tafsir, 'passages', tafsirPackFileName),
        'recitation': (() => recitation, 'files', recitationPackFileName),
      };
      for (final MapEntry(key: kind, value: (json, count, file))
          in cases.entries) {
        test('$kind is not a kind of format 1', () {
          expect(
            parse(from(json(), (json) => json['format_version'] = 1)),
            unreadableBecause('kind $kind is not a kind of format version 1'),
          );
        });

        test('$kind has no edition, font or surah digests', () {
          for (final field in ['edition', 'font', 'surah_sha256']) {
            expect(
              parse(from(json(), (json) => json[field] = valid[field])),
              unreadableBecause('manifest has unknown field $field'),
              reason: field,
            );
          }
        });

        test('$kind counts its $count, at least one, and nothing else', () {
          expect(
            parse(from(json(), (json) => json.at(['counts'])[count] = 0)),
            unreadableBecause('manifest.counts.$count is not positive'),
          );
          expect(
            parse(from(json(), (json) => json['counts'] = valid['counts'])),
            unreadable,
          );
        });

        test('$kind lists exactly $file', () {
          expect(
            parse(
              from(
                json(),
                (json) => json.at(['files', 0])['name'] = textPackFileName,
              ),
            ),
            unreadableBecause('files of a $kind pack is not exactly $file'),
          );
        });

        test('$kind names a riwaya', () {
          expect(
            parse(from(json(), (json) => json['riwaya'] = null)),
            unreadableBecause('riwaya of a $kind pack is null'),
          );
        });

        test('$kind takes its own source role only', () {
          expect(
            parse(
              from(json(), (json) => json.at(['sources', 0])['role'] = 'text'),
            ),
            unreadableBecause('sources of a $kind pack name the role text'),
          );
        });
      }
    });

    test('a text pack takes no tafsir or recitation source', () {
      for (final role in ['tafsir', 'recitation']) {
        expect(
          parse(edited((json) => json.at(['sources', 1])['role'] = role)),
          unreadable,
          reason: role,
        );
      }
    });
  });
}

extension on Json {
  void apply(void Function(Json json) edit) => edit(this);

  Json _parentOf(List<Object> path) => at(path.sublist(0, path.length - 1));

  Object? get(List<Object> path) => _parentOf(path)[path.last as String];

  void set(List<Object> path, Object? value) =>
      _parentOf(path)[path.last as String] = value;

  void delete(List<Object> path) => _parentOf(path).remove(path.last);

  /// The object at [path] of keys and list indexes.
  Json at(List<Object> path) {
    Object? node = this;
    for (final step in path) {
      node = switch ((node, step)) {
        (final Json map, final String key) => map[key],
        (final List<Object?> list, final int index) => list[index],
        _ => throw StateError('no ${path.join('.')}'),
      };
    }
    return node! as Json;
  }
}
