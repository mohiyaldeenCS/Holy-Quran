import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/data/repositories/local_pack_repository.dart';
import 'package:holyquran/data/repositories/pack_quran_text_repository.dart';
import 'package:holyquran/data/services/manifest_signature.dart';
import 'package:holyquran/data/services/pack_database.dart';
import 'package:holyquran/data/services/pack_file_service.dart';
import 'package:holyquran/domain/models/edition_map.dart';
import 'package:holyquran/domain/models/pack_manifest.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/domain/models/verified_pack.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/quran_text.dart';
import 'package:holyquran/utils/result.dart';

import '../../testing/golden.dart';
import '../../testing/packs/raw_pack.dart';
import '../../testing/packs/synthetic_pack.dart'
    show amiriQuranFontPath, textFileName;
import 'unicode_categories.dart';

// The PRD section 9.4 integrity suite for one text pack (D-067). Every
// expected value comes from the pack's manifest; no count of surahs or ayat is
// written here. Each check returns the problems it found, so the checks can
// be shown to catch faulty packs (synthetic_pack_integrity_test.dart).

/// Defines the integrity tests for the pack in the directory [packDirectory]
/// completes with, under [description].
void definePackIntegritySuite(
  String description,
  Future<String> Function() packDirectory,
) {
  group(description, () {
    PackUnderTest? loaded;
    PackUnderTest pack() => loaded ?? fail('The pack was not loaded.');

    setUpAll(
      () async => loaded = await PackUnderTest.load(await packDirectory()),
    );
    tearDownAll(() => loaded?.close());

    test('passes verification', timeout: _timeout, () {
      final verification = pack().verification;
      expect(
        verification,
        isA<Ok<VerifiedPack>>(),
        reason: switch (verification) {
          Failure(:final error) => '$error',
          Ok() => null,
        },
      );
    });

    test(
      'opens through the text repository',
      timeout: _timeout,
      () => pack().openRepository(),
    );

    for (final MapEntry(key: name, value: check) in packChecks.entries) {
      test(
        name,
        timeout: _timeout,
        () async => expectNoProblems(await check(pack())),
      );
    }

    testWidgets(
      'QuranText draws the stored bytes of every ayah and basmala',
      timeout: _timeout,
      (tester) async {
        final texts = (await tester.runAsync(() => _displayedTexts(pack())))!;
        expect(texts, isNotEmpty);
        final problems = <String>[];
        for (final (where, text, stored) in texts) {
          await tester.pumpWidget(
            goldenApp(
              ReadingTheme.paper,
              QuranText(text, size: QuranTextSize.ayah),
            ),
          );
          final drawn = find.descendant(
            of: find.byType(QuranText),
            matching: find.byType(RichText),
          );
          problems.addAll(
            drawnTextProblems(
              where,
              tester.widget<RichText>(drawn).text,
              tester.renderObject<RenderParagraph>(drawn).text,
              stored,
            ),
          );
        }
        expectNoProblems(problems);
      },
    );
  });
}

/// A full pack has thousands of ayat and tens of thousands of words.
const _timeout = Timeout.factor(10);

/// Fails with at most the first problems, and how many there were.
void expectNoProblems(List<String> problems) => expect(
  problems.take(40).toList(),
  isEmpty,
  reason: '${problems.length} problems',
);

typedef PackCheck = Future<List<String>> Function(PackUnderTest pack);

final packChecks = <String, PackCheck>{
  'has the header of a text pack: bytes 18 and 19, application_id, '
          'user_version':
      headerProblems,
  'has the tables and columns of format v1, STRICT': schemaProblems,
  'sits in the directories its id and version name': locationProblems,
  'numbers its surahs and ayat contiguously from 1': numberingProblems,
  'holds the rows its manifest counts': countProblems,
  'has surah digests equal to the manifest, in production and independently':
      digestProblems,
  'gives every name, basmala and ayah as its stored bytes': storedTextProblems,
  'stores no text that begins with EF BB BF': bomProblems,
  'reads the options of every source as manifest.json gives them':
      sourceOptionsProblems,
  'has word and mark spans in bounds and in order that rejoin to the ayah':
      spanProblemsOfPack,
  'has only the separator U+0020 outside its word and mark spans':
      gapProblemsOfPack,
  'has a letter in every word and none in any mark': letterProblemsOfPack,
  'has divisions and sajdas that refer to its ayat': referenceProblems,
  'names the pinned Amiri Quran font file': fontProblems,
};

/// A pack directory, verified through the production path and opened by the
/// independent reader.
final class PackUnderTest {
  PackUnderTest._(this.directory, this.verification, this._raw, this._rawError);

  static Future<PackUnderTest> load(String directory) async {
    final verification = await const LocalPackRepository(
      files: PackFileService(),
      signatures: SignatureNotConfigured(),
    ).verify(directory);
    RawPack? raw;
    Exception? rawError;
    try {
      raw = RawPack.open(File('$directory/$textFileName'));
    } on Exception catch (error) {
      rawError = error;
    }
    return PackUnderTest._(directory, verification, raw, rawError);
  }

  final String directory;
  final Result<VerifiedPack> verification;
  final RawPack? _raw;
  final Exception? _rawError;
  final _closers = <void Function()>[];

  File get textFile => File('$directory/$textFileName');

  VerifiedPack get verified => switch (verification) {
    Ok(:final value) => value,
    Failure(:final error) => fail('The pack was not verified: $error'),
  };

  PackManifest get manifest => verified.manifest;

  RawPack get raw =>
      _raw ??
      fail('The independent reader could not open the pack: $_rawError');

  /// A repository of its own, so that a check that disables it leaves the
  /// other checks unaffected.
  PackQuranTextRepository openRepository() {
    switch (PackQuranTextRepository.open(verified)) {
      case Ok(:final value):
        _closers.add(value.close);
        return value;
      case Failure(:final error):
        fail('The text repository did not open: $error');
    }
  }

  PackDatabase openDatabase() {
    final database = PackDatabase.open(
      textFile.path,
      formatVersion: manifest.formatVersion,
    );
    _closers.add(database.close);
    return database;
  }

  void close() {
    for (final close in _closers) {
      close();
    }
    _raw?.close();
  }
}

T? _value<T>(Result<T> result, List<String> problems, String what) {
  switch (result) {
    case Ok(:final value):
      return value;
    case Failure(:final error):
      problems.add('$what: $error');
      return null;
  }
}

/// Null when [actual] holds the same bytes as [stored]; otherwise their
/// lengths, digests and the first offset at which they differ. Never the
/// bytes: the suite runs on the real text in CI, and its log must not hold it.
String? byteMismatch(List<int> actual, List<int> stored) {
  if (_sameBytes(actual, stored)) return null;
  var at = 0;
  while (at < actual.length && at < stored.length && actual[at] == stored[at]) {
    at++;
  }
  return '${actual.length} bytes, sha256 ${sha256.convert(actual)}, where '
      '${stored.length} bytes, sha256 ${sha256.convert(stored)}, are stored; '
      'they differ from byte $at';
}

/// The problems of a [RichText] that should draw [stored]: its span [given]
/// and the span its paragraph [laidOut] lays out.
List<String> drawnTextProblems(
  String where,
  InlineSpan given,
  InlineSpan laidOut,
  List<int> stored,
) {
  final problems = <String>[];
  if (given is! TextSpan) {
    problems.add('$where: RichText holds a span that is not a TextSpan');
  } else {
    if (given.children case final children?) {
      problems.add('$where: the span has ${children.length} child spans');
    }
    final text = given.text;
    if (text == null) {
      problems.add('$where: the span has no text');
    } else if (byteMismatch(utf8.encode(text), stored) case final m?) {
      problems.add('$where: RichText holds $m');
    }
  }
  if (byteMismatch(utf8.encode(laidOut.toPlainText()), stored) case final m?) {
    problems.add('$where: the paragraph lays out $m');
  }
  return problems;
}

bool _sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _isSequence(Iterable<int> numbers, int length) {
  final list = numbers.toList();
  if (list.length != length) return false;
  for (var i = 0; i < length; i++) {
    if (list[i] != i + 1) return false;
  }
  return true;
}

Future<List<String>> headerProblems(PackUnderTest pack) async {
  final header = await RawHeader.read(pack.textFile);
  final formatVersion = pack.manifest.formatVersion;
  return [
    if (header.bytes.length < 100 || !header.hasMagic) 'not an SQLite 3 file',
    if (header.writeVersion != 1)
      'header byte 18 is ${header.writeVersion}, not 1',
    if (header.readVersion != 1)
      'header byte 19 is ${header.readVersion}, not 1',
    if (header.textEncoding != 1)
      'text encoding is ${header.textEncoding}, not UTF-8 (1)',
    if (header.applicationId != hqpkApplicationId)
      'application_id is ${header.applicationId}, not $hqpkApplicationId',
    if (header.userVersion != formatVersion)
      'user_version is ${header.userVersion}, not $formatVersion',
    if (header.freelistPages != 0)
      '${header.freelistPages} free pages: the build did not end with VACUUM',
  ];
}

/// The tables of docs/CONTENT_PACKS.md, "Text pack": name, whether it is
/// WITHOUT ROWID, and its columns as [RawColumn] prints them.
const _schema = {
  'ayah': (
    true,
    [
      'surah INTEGER NOT NULL pk1',
      'number INTEGER NOT NULL pk2',
      'text TEXT NOT NULL',
    ],
  ),
  'division': (
    true,
    [
      'kind TEXT NOT NULL pk1',
      'number INTEGER NOT NULL pk2',
      'surah INTEGER NOT NULL',
      'ayah INTEGER NOT NULL',
    ],
  ),
  'mark': (
    true,
    [
      'surah INTEGER NOT NULL pk1',
      'ayah INTEGER NOT NULL pk2',
      'number INTEGER NOT NULL pk3',
      'after_word INTEGER NOT NULL',
      'start_offset INTEGER NOT NULL',
      'end_offset INTEGER NOT NULL',
    ],
  ),
  'sajda': (true, ['surah INTEGER NOT NULL pk1', 'ayah INTEGER NOT NULL pk2']),
  'surah': (
    false,
    [
      'number INTEGER pk1',
      'name TEXT NOT NULL',
      'ayah_count INTEGER NOT NULL',
      'revelation_place TEXT',
      'revelation_order INTEGER',
      'basmala TEXT',
    ],
  ),
  'word': (
    true,
    [
      'surah INTEGER NOT NULL pk1',
      'ayah INTEGER NOT NULL pk2',
      'number INTEGER NOT NULL pk3',
      'start_offset INTEGER NOT NULL',
      'end_offset INTEGER NOT NULL',
    ],
  ),
};

Future<List<String>> schemaProblems(PackUnderTest pack) async {
  final raw = pack.raw;
  final tables = raw.tables();
  return [
    if (raw.encoding != 'UTF-8') 'PRAGMA encoding is ${raw.encoding}',
    if ('${tables.map((t) => t.name)}' != '${_schema.keys}')
      'the tables are ${tables.map((t) => t.name)}, not ${_schema.keys}',
    for (final table in tables)
      if (_schema[table.name] case (final withoutRowid, final columns)) ...[
        if (!table.strict) '${table.name} is not STRICT',
        if (table.withoutRowid != withoutRowid)
          '${table.name} is ${table.withoutRowid ? '' : 'not '}WITHOUT ROWID',
        if ('${raw.columns(table.name)}' != '$columns')
          '${table.name} has the columns ${raw.columns(table.name)}',
      ],
    if (raw.integrityCheck().join() != 'ok')
      'integrity_check reports ${raw.integrityCheck()}',
    if (raw.foreignKeyViolations() != 0)
      '${raw.foreignKeyViolations()} rows break a foreign key',
  ];
}

/// `id` and `version` name the two directories the pack sits in. They are
/// read from the manifest file itself, since verification refuses a pack
/// that sits elsewhere.
Future<List<String>> locationProblems(PackUnderTest pack) async {
  final segments = Directory(
    pack.directory,
  ).absolute.uri.pathSegments.where((segment) => segment.isNotEmpty).toList();
  final manifest =
      jsonDecode(await File('${pack.directory}/manifest.json').readAsString())
          as Map<String, Object?>;
  final expected = ['${manifest['id']}', '${manifest['version']}'];
  final found = segments.length < 2
      ? segments
      : segments.sublist(segments.length - 2);
  return [
    if ('$found' != '$expected')
      'the pack sits in ${found.join('/')}, not ${expected.join('/')}',
  ];
}

Future<List<String>> numberingProblems(PackUnderTest pack) async {
  final problems = <String>[];
  final raw = pack.raw;
  final stored = raw.surahs();
  for (final (index, surah) in stored.indexed) {
    if (surah.number != index + 1) {
      problems.add('surah ${index + 1} is numbered ${surah.number}');
    }
    final numbers = [for (final (number, _) in raw.ayat(surah.number)) number];
    if (!_isSequence(numbers, surah.ayahCount)) {
      problems.add(
        'surah ${surah.number}: ayat numbered $numbers, '
        'not 1 to ${surah.ayahCount}',
      );
    }
  }
  final repository = pack.openRepository();
  final surahs = _value(await repository.surahs(), problems, 'surah list');
  if (surahs != null) {
    if (!_isSequence(surahs.map((s) => s.number), stored.length)) {
      problems.add(
        'the repository lists surahs ${surahs.map((s) => s.number)}',
      );
    }
    for (final (index, surah) in surahs.indexed) {
      if (index < stored.length && surah.ayahCount != stored[index].ayahCount) {
        problems.add(
          'surah ${surah.number}: the repository counts '
          '${surah.ayahCount} ayat, the file ${stored[index].ayahCount}',
        );
      }
    }
  }
  return problems;
}

Future<List<String>> countProblems(PackUnderTest pack) async {
  final problems = <String>[];
  final counts = pack.manifest.counts;
  final raw = pack.raw;
  void expectCount(String field, int? listed, int? found, String where) {
    if (listed != found) {
      problems.add('counts.$field is $listed; $where holds $found');
    }
  }

  final stored = raw.surahs();
  expectCount('surahs', counts.surahs, raw.count('surah'), 'the file');
  expectCount('ayat', counts.ayat, raw.count('ayah'), 'the file');
  expectCount(
    'ayat',
    counts.ayat,
    stored.fold<int>(0, (sum, s) => sum + s.ayahCount),
    'the sum of surah.ayah_count',
  );
  expectCount('words', counts.words, raw.count('word'), 'the file');
  expectCount('marks', counts.marks, raw.count('mark'), 'the file');
  final divisions = raw.divisionCounts();
  for (final division in Division.values) {
    expectCount(
      'divisions.${division.name}',
      counts.divisions[division],
      divisions[division.name],
      'the file',
    );
  }
  expectCount(
    'divisions',
    counts.divisions.values.fold<int>(0, (sum, n) => sum + n),
    raw.count('division'),
    'the division table',
  );
  expectCount('sajdas', counts.sajdas, raw.count('sajda'), 'the file');

  final keys = pack.manifest.surahSha256.keys.toList()..sort();
  if (!_isSequence(keys, counts.surahs)) {
    problems.add('surah_sha256 has keys $keys, not 1 to ${counts.surahs}');
  }

  final repository = pack.openRepository();
  final surahs = _value(await repository.surahs(), problems, 'surah list');
  if (surahs != null) {
    expectCount('surahs', counts.surahs, surahs.length, 'the repository');
    expectCount(
      'ayat',
      counts.ayat,
      surahs.fold<int>(0, (sum, s) => sum + s.ayahCount),
      'the repository',
    );
  }
  final map = _value(await repository.editionMap(), problems, 'edition map');
  if (map != null) {
    for (final division in Division.values) {
      expectCount(
        'divisions.${division.name}',
        counts.divisions[division],
        map.count(division),
        'the edition map',
      );
    }
    expectCount('sajdas', counts.sajdas, map.sajdas.length, 'the edition map');
  }
  if (await _spanCounts(pack, repository, problems) case (
    final words,
    final marks,
  )) {
    expectCount('words', counts.words, words, 'the repository');
    expectCount('marks', counts.marks, marks, 'the repository');
  }
  return problems;
}

/// The words and marks the repository gives over every stored ayah, or null
/// after the first read that fails.
Future<(int, int)?> _spanCounts(
  PackUnderTest pack,
  PackQuranTextRepository repository,
  List<String> problems,
) async {
  var words = 0;
  var marks = 0;
  for (final surah in pack.raw.surahs()) {
    for (final (number, _) in pack.raw.ayat(surah.number)) {
      final address = QuranAddress(repository.riwaya, surah.number, number);
      final w = _value(await repository.words(address), problems, '$address');
      if (w == null) return null;
      final m = _value(await repository.marks(address), problems, '$address');
      if (m == null) return null;
      words += w.length;
      marks += m.length;
    }
  }
  return (words, marks);
}

/// Each source's `options`, as the manifest parser gives them, against the
/// value manifest.json holds: null or an object of strings, numbers and
/// booleans.
Future<List<String>> sourceOptionsProblems(PackUnderTest pack) async {
  final json =
      jsonDecode(await File('${pack.directory}/manifest.json').readAsString())
          as Map<String, Object?>;
  return optionsProblems([
    for (final source in pack.manifest.sources) source.options,
  ], json['sources']);
}

/// The problems of the parsed [options] against the `sources` array
/// [sources] of manifest.json. Names fields, never values.
List<String> optionsProblems(
  List<Map<String, Object>?> options,
  Object? sources,
) {
  if (sources is! List<Object?> || sources.length != options.length) {
    return ['manifest.json does not list ${options.length} sources'];
  }
  final problems = <String>[];
  for (final (index, parsed) in options.indexed) {
    final where = 'sources[$index].options';
    final source = sources[index];
    if (source is! Map<String, Object?> || !source.containsKey('options')) {
      problems.add('$where is missing from manifest.json');
      continue;
    }
    final given = source['options'];
    if (given == null && parsed == null) continue;
    if (given is! Map<String, Object?> ||
        parsed == null ||
        given.length != parsed.length) {
      problems.add('$where is not read as manifest.json gives it');
      continue;
    }
    for (final MapEntry(:key, :value) in given.entries) {
      if (value is! String && value is! num && value is! bool) {
        problems.add('$where[$key] is not a string, number or boolean');
      } else if (parsed[key] != value) {
        problems.add('$where[$key] is not read as manifest.json gives it');
      }
    }
  }
  return problems;
}

Future<List<String>> digestProblems(PackUnderTest pack) async {
  final problems = <String>[];
  final listed = pack.manifest.surahSha256;
  final database = pack.openDatabase();
  final numbers = [for (final surah in pack.raw.surahs()) surah.number];
  for (final surah in numbers) {
    final expected = listed[surah];
    if (database.surahSha256(surah) != expected) {
      problems.add(
        'surah $surah: the production digest differs from the '
        'manifest',
      );
    }
    if (pack.raw.surahDigestOf(surah) != expected) {
      problems.add(
        'surah $surah: the independent digest differs from the '
        'manifest',
      );
    }
  }
  for (final surah in listed.keys) {
    if (!numbers.contains(surah)) {
      problems.add('surah_sha256 lists surah $surah, which the file lacks');
    }
  }
  return problems;
}

Future<List<String>> storedTextProblems(PackUnderTest pack) async {
  final problems = <String>[];
  final repository = pack.openRepository();
  final surahs = _value(await repository.surahs(), problems, 'surah list');
  if (surahs == null) return problems;
  final stored = {for (final surah in pack.raw.surahs()) surah.number: surah};
  void expectBytes(String where, PackText? text, List<int>? bytes) {
    if ((text == null) != (bytes == null)) {
      problems.add(
        '$where: the app gives ${text == null ? 'none' : 'a text'}, '
        'the file ${bytes == null ? 'none' : 'a text'}',
      );
    } else if (text != null) {
      if (byteMismatch(utf8.encode(text.verbatim), bytes!) case final m?) {
        problems.add('$where: the app gives $m');
      }
    }
  }

  for (final surah in surahs) {
    final row = stored[surah.number];
    if (row == null) {
      problems.add('surah ${surah.number} is not in the file');
      continue;
    }
    expectBytes('surah ${surah.number} name', surah.name, row.name);
    final basmala = await repository.basmala(surah.number);
    if (basmala case Ok(:final value)) {
      expectBytes('surah ${surah.number} basmala', value, row.basmala);
    } else {
      _value(basmala, problems, 'surah ${surah.number} basmala');
    }
    for (final (number, bytes) in pack.raw.ayat(surah.number)) {
      final address = QuranAddress(repository.riwaya, surah.number, number);
      final text = _value(
        await repository.ayahText(address),
        problems,
        '$address',
      );
      if (text != null) expectBytes('$address', text, bytes);
    }
  }
  return problems;
}

Future<List<String>> bomProblems(PackUnderTest pack) async {
  bool startsWithBom(List<int>? bytes) =>
      bytes != null &&
      bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF;
  return [
    for (final surah in pack.raw.surahs()) ...[
      if (startsWithBom(surah.name)) 'surah ${surah.number} name',
      if (startsWithBom(surah.basmala)) 'surah ${surah.number} basmala',
      for (final (number, bytes) in pack.raw.ayat(surah.number))
        if (startsWithBom(bytes)) 'ayah ${surah.number}:$number',
    ],
  ];
}

/// A word `(number, start, end)` and a mark `(number, after_word, start,
/// end)` as [RawPack] gives them, in UTF-16 code units.
typedef StoredWord = (int, int, int);
typedef StoredMark = (int, int, int, int);

/// The spans are checked twice: as the file stores them, so that the check
/// does not depend on the production path accepting the pack, and as the
/// repository gives them.
Future<List<String>> spanProblemsOfPack(PackUnderTest pack) async {
  final problems = <String>[];
  final repository = pack.openRepository();
  for (final (address, text, storedWords, storedMarks) in _storedAyat(pack)) {
    final where = '$address';
    problems.addAll(spanProblems(where, text, storedWords, storedMarks));
    final verbatim = _value(
      await repository.ayahText(address),
      problems,
      where,
    );
    final words = _value(
      await repository.words(address),
      problems,
      '$where words',
    );
    final marks = _value(
      await repository.marks(address),
      problems,
      '$where marks',
    );
    if (verbatim == null || words == null || marks == null) continue;
    final wordRows = [for (final w in words) (w.number, w.start, w.end)];
    final markRows = [
      for (final m in marks) (m.number, m.afterWord, m.start, m.end),
    ];
    if ('$wordRows' != '$storedWords') {
      problems.add('$where: the repository gives other words than the file');
    }
    if ('$markRows' != '$storedMarks') {
      problems.add('$where: the repository gives other marks than the file');
    }
    problems.addAll(spanProblems(where, verbatim.verbatim, wordRows, markRows));
  }
  return problems;
}

Future<List<String>> gapProblemsOfPack(PackUnderTest pack) async => [
  for (final (address, text, words, marks) in _storedAyat(pack))
    ...gapProblems('$address', text, words, marks),
];

Future<List<String>> letterProblemsOfPack(PackUnderTest pack) async => [
  for (final (address, text, words, marks) in _storedAyat(pack))
    ...letterProblems('$address', text, words, marks),
];

/// Every stored ayah with its address, its text decoded from the stored
/// bytes, and its stored words and marks.
Iterable<(QuranAddress, String, List<StoredWord>, List<StoredMark>)>
_storedAyat(PackUnderTest pack) sync* {
  final raw = pack.raw;
  final riwaya = pack.manifest.riwaya ?? fail('The manifest has no riwaya.');
  for (final surah in raw.surahs()) {
    for (final (number, bytes) in raw.ayat(surah.number)) {
      yield (
        QuranAddress(riwaya, surah.number, number),
        _decodedKeepingBom(bytes),
        raw.words(surah.number, number),
        raw.marks(surah.number, number),
      );
    }
  }
}

/// [bytes] decoded as UTF-8 with a leading U+FEFF kept, which Dart's decoder
/// drops.
String _decodedKeepingBom(List<int> bytes) {
  final text = utf8.decode(bytes, allowMalformed: true);
  final bom =
      bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF;
  return bom ? '\u{FEFF}$text' : text;
}

/// The problems of the word and mark spans of the ayah [text], taken together
/// (docs/CONTENT_PACKS.md, "Word and mark offsets"): each kind numbered 1 to
/// n, every span non-empty, within the ayah, on no surrogate pair and after
/// the span before, and each mark's after_word the number of words before
/// it. The ayah is rejoined from the slices and the gaps the text itself has
/// between them; nothing is added.
List<String> spanProblems(
  String where,
  String text,
  List<StoredWord> words,
  List<StoredMark> marks,
) {
  final problems = <String>[
    for (final (index, (number, _, _)) in words.indexed)
      if (number != index + 1) '$where: word ${index + 1} is numbered $number',
    for (final (index, (number, _, _, _)) in marks.indexed)
      if (number != index + 1) '$where: mark ${index + 1} is numbered $number',
  ];
  final pieces = <String>[];
  var previousEnd = 0;
  var w = 0;
  var m = 0;
  while (w < words.length || m < marks.length) {
    final isWord =
        m == marks.length || (w < words.length && words[w].$2 <= marks[m].$3);
    final (kind, number, start, end) = isWord
        ? ('word', words[w].$1, words[w].$2, words[w].$3)
        : ('mark', marks[m].$1, marks[m].$3, marks[m].$4);
    if (!isWord && marks[m].$2 != w) {
      problems.add(
        '$where: mark $number has after_word ${marks[m].$2}, not $w',
      );
    }
    if (isWord) {
      w++;
    } else {
      m++;
    }
    if (start < previousEnd || start >= end || end > text.length) {
      problems.add(
        '$where: $kind $number span [$start, $end) is not after the span '
        'before, not empty and within ${text.length} code units',
      );
      continue;
    }
    for (final offset in [start, end]) {
      if (_splitsSurrogatePair(text, offset)) {
        problems.add(
          '$where: $kind $number offset $offset splits a surrogate pair',
        );
      }
    }
    pieces
      ..add(text.substring(previousEnd, start))
      ..add(text.substring(start, end));
    previousEnd = end;
  }
  pieces.add(text.substring(previousEnd));
  final rejoined = <int>[for (final piece in pieces) ...utf8.encode(piece)];
  if (pieces.join() != text || !_sameBytes(rejoined, utf8.encode(text))) {
    problems.add('$where: the slices and gaps do not rejoin to the ayah');
  }
  return problems;
}

/// The separator of the text source between tokens (docs/CONTENT_PACKS.md,
/// "Word and mark offsets": what lies between spans is the source's own
/// separator).
const separator = 0x20;

/// Each run of code units of [text] that no word or mark covers, and that
/// holds anything but [separator]: by its offsets and its first other code
/// point. With every word holding a letter and every mark none, this proves
/// that no letter lies outside both.
List<String> gapProblems(
  String where,
  String text,
  List<StoredWord> words,
  List<StoredMark> marks,
) {
  final covered = List.filled(text.length, false);
  for (final (start, end) in [
    for (final (_, start, end) in words) (start, end),
    for (final (_, _, start, end) in marks) (start, end),
  ]) {
    for (var i = start < 0 ? 0 : start; i < end && i < text.length; i++) {
      covered[i] = true;
    }
  }
  final problems = <String>[];
  var i = 0;
  while (i < text.length) {
    if (covered[i]) {
      i++;
      continue;
    }
    final gapStart = i;
    int? other;
    while (i < text.length && !covered[i]) {
      if (other == null && text.codeUnitAt(i) != separator) other = i;
      i++;
    }
    if (other != null) {
      problems.add(
        '$where: the gap [$gapStart, $i) holds '
        '${codePointName(_codePointAt(text, other))} at offset $other',
      );
    }
  }
  return problems;
}

/// A word that holds no letter of [isLetter], and a mark that holds one, by
/// its span and, for a mark, its first letter. Spans out of bounds are left
/// to [spanProblems].
List<String> letterProblems(
  String where,
  String text,
  List<StoredWord> words,
  List<StoredMark> marks,
) {
  bool inBounds(int start, int end) =>
      0 <= start && start < end && end <= text.length;
  int? firstLetter(int start, int end) {
    for (var i = start; i < end; i++) {
      if (isLetter(_codePointAt(text, i))) return i;
    }
    return null;
  }

  final problems = [
    for (final (number, start, end) in words)
      if (inBounds(start, end) && firstLetter(start, end) == null)
        '$where: word $number [$start, $end) holds no letter',
  ];
  for (final (number, _, start, end) in marks) {
    if (!inBounds(start, end)) continue;
    if (firstLetter(start, end) case final at?) {
      final letter = codePointName(_codePointAt(text, at));
      problems.add(
        '$where: mark $number [$start, $end) holds the letter $letter at '
        'offset $at',
      );
    }
  }
  return problems;
}

/// The code point at UTF-16 [offset] of [text]: a whole surrogate pair when
/// one starts there, else the code unit.
int _codePointAt(String text, int offset) {
  final unit = text.codeUnitAt(offset);
  if ((unit & 0xFC00) == 0xD800 && offset + 1 < text.length) {
    final low = text.codeUnitAt(offset + 1);
    if ((low & 0xFC00) == 0xDC00) {
      return 0x10000 + ((unit & 0x3FF) << 10) + (low & 0x3FF);
    }
  }
  return unit;
}

bool _splitsSurrogatePair(String text, int offset) =>
    offset > 0 &&
    offset < text.length &&
    (text.codeUnitAt(offset - 1) & 0xFC00) == 0xD800 &&
    (text.codeUnitAt(offset) & 0xFC00) == 0xDC00;

Future<List<String>> referenceProblems(PackUnderTest pack) async {
  final problems = <String>[];
  final raw = pack.raw;
  final ayahCounts = {for (final s in raw.surahs()) s.number: s.ayahCount};
  bool exists(int surah, int ayah) =>
      ayah >= 1 && ayah <= (ayahCounts[surah] ?? 0);
  int compare((int, int) a, (int, int) b) =>
      a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2);

  final byKind = <String, List<(int, int, int)>>{};
  for (final (kind, number, surah, ayah) in raw.divisions()) {
    (byKind[kind] ??= []).add((number, surah, ayah));
    if (!exists(surah, ayah)) {
      problems.add(
        '$kind $number refers to $surah:$ayah, not an ayah of the '
        'pack',
      );
    }
  }
  for (final MapEntry(key: kind, value: rows) in byKind.entries) {
    if (!_isSequence(rows.map((r) => r.$1), rows.length)) {
      problems.add('$kind units are numbered ${rows.map((r) => r.$1)}');
    }
    for (var i = 1; i < rows.length; i++) {
      if (compare((rows[i].$2, rows[i].$3), (rows[i - 1].$2, rows[i - 1].$3)) <=
          0) {
        problems.add(
          '$kind ${rows[i].$1} does not start after '
          '$kind ${rows[i - 1].$1}',
        );
      }
    }
  }
  final sajdas = raw.sajdas();
  for (final (surah, ayah) in sajdas) {
    if (!exists(surah, ayah)) {
      problems.add('a sajda refers to $surah:$ayah, not an ayah of the pack');
    }
  }

  final repository = pack.openRepository();
  final map = _value(await repository.editionMap(), problems, 'edition map');
  if (map == null) return problems;
  final riwaya = repository.riwaya;
  for (final division in Division.values) {
    final rows = byKind[division.name] ?? const [];
    if (map.count(division) != rows.length) {
      problems.add(
        'the edition map has ${map.count(division)} '
        '${division.name} units, the file ${rows.length}',
      );
      continue;
    }
    for (final (index, (number, surah, ayah)) in rows.indexed) {
      if (exists(surah, ayah) &&
          map.startOf(division, index + 1) !=
              QuranAddress(riwaya, surah, ayah)) {
        problems.add(
          'the edition map starts ${division.name} $number '
          'elsewhere than the file',
        );
      }
    }
  }
  final storedSajdas = {
    for (final (surah, ayah) in sajdas)
      if (exists(surah, ayah)) QuranAddress(riwaya, surah, ayah),
  };
  if (map.sajdas.length != storedSajdas.length ||
      !map.sajdas.containsAll(storedSajdas)) {
    problems.add('the edition map has other sajdas than the file');
  }
  return problems;
}

Future<List<String>> fontProblems(PackUnderTest pack) async {
  final font = pack.manifest.font;
  final bytes = await File(amiriQuranFontPath).readAsBytes();
  final family = _fontName(bytes, 16) ?? _fontName(bytes, 1);
  final version = RegExp(
    r'^Version (\d+\.\d+)',
  ).firstMatch(_fontName(bytes, 5) ?? '')?[1];
  return [
    if (sha256.convert(bytes).toString() != font.sha256)
      'font.sha256 is not the SHA-256 of $amiriQuranFontPath',
    if (font.family != AppFonts.quran)
      'font.family is ${font.family}; QuranText draws with ${AppFonts.quran}',
    if (font.family != family)
      'font.family is ${font.family}; $amiriQuranFontPath is $family',
    if (font.version != version)
      'font.version is ${font.version}; $amiriQuranFontPath is $version',
  ];
}

/// A record of the `name` table of a TrueType font: Windows platform,
/// Unicode BMP, US English. Null when the font has none.
String? _fontName(Uint8List font, int nameId) {
  final data = ByteData.sublistView(font);
  for (var i = 0; i < data.getUint16(4); i++) {
    final entry = 12 + 16 * i;
    if (String.fromCharCodes(font, entry, entry + 4) != 'name') continue;
    final table = data.getUint32(entry + 8);
    final strings = table + data.getUint16(table + 4);
    for (var j = 0; j < data.getUint16(table + 2); j++) {
      final record = table + 6 + 12 * j;
      if (data.getUint16(record) == 3 &&
          data.getUint16(record + 2) == 1 &&
          data.getUint16(record + 4) == 0x409 &&
          data.getUint16(record + 6) == nameId) {
        final start = strings + data.getUint16(record + 10);
        return String.fromCharCodes([
          for (var k = 0; k < data.getUint16(record + 8); k += 2)
            data.getUint16(start + k),
        ]);
      }
    }
  }
  return null;
}

/// Every basmala and ayah as the repository gives it, with its stored bytes.
Future<List<(String, PackText, Uint8List)>> _displayedTexts(
  PackUnderTest pack,
) async {
  final repository = pack.openRepository();
  final texts = <(String, PackText, Uint8List)>[];
  T ok<T>(Result<T> result, String what) => switch (result) {
    Ok(:final value) => value,
    Failure(:final error) => fail('$what: $error'),
  };
  for (final surah in pack.raw.surahs()) {
    final basmala = ok(await repository.basmala(surah.number), 'basmala');
    if (basmala != null) {
      texts.add((
        'surah ${surah.number} basmala',
        basmala,
        surah.basmala ?? fail('surah ${surah.number}: no basmala is stored'),
      ));
    }
    for (final (number, bytes) in pack.raw.ayat(surah.number)) {
      final address = QuranAddress(repository.riwaya, surah.number, number);
      texts.add((
        '$address',
        ok(await repository.ayahText(address), '$address'),
        bytes,
      ));
    }
  }
  return texts;
}
