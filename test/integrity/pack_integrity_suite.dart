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
          final span = tester.widget<RichText>(drawn).text as TextSpan;
          expect(span.children, isNull, reason: where);
          expect(utf8.encode(span.text!), stored, reason: where);
          expect(
            utf8.encode(
              tester.renderObject<RenderParagraph>(drawn).text.toPlainText(),
            ),
            stored,
            reason: where,
          );
        }
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
  'has word spans in bounds and in order that rejoin to the ayah':
      wordSpanProblemsOfPack,
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
    } else if (text != null &&
        !_sameBytes(utf8.encode(text.verbatim), bytes!)) {
      problems.add('$where: the app gives other bytes than the file holds');
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

/// The spans are checked twice: as the file stores them, so that the check
/// does not depend on the production path accepting the pack, and as the
/// repository gives them.
Future<List<String>> wordSpanProblemsOfPack(PackUnderTest pack) async {
  final problems = <String>[];
  final repository = pack.openRepository();
  for (final surah in pack.raw.surahs()) {
    for (final (number, bytes) in pack.raw.ayat(surah.number)) {
      final address = QuranAddress(repository.riwaya, surah.number, number);
      final stored = pack.raw.words(surah.number, number);
      problems.addAll(
        wordSpanProblems('$address', _decodedKeepingBom(bytes), stored),
      );
      final text = _value(
        await repository.ayahText(address),
        problems,
        '$address',
      );
      final spans = _value(
        await repository.words(address),
        problems,
        '$address words',
      );
      if (text == null || spans == null) continue;
      final words = [for (final s in spans) (s.number, s.start, s.end)];
      if ('$words' != '$stored') {
        problems.add(
          '$address: the repository gives other spans than the file',
        );
      }
      problems.addAll(wordSpanProblems('$address', text.verbatim, words));
    }
  }
  return problems;
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

/// The problems of the word spans [words], `(number, start, end)` in UTF-16
/// code units, of the ayah [text]. The ayah is rejoined from its slices and
/// the gaps the text itself has between them; nothing is added.
List<String> wordSpanProblems(
  String where,
  String text,
  List<(int, int, int)> words,
) {
  final problems = <String>[];
  final pieces = <String>[];
  var previousEnd = 0;
  for (final (index, (number, start, end)) in words.indexed) {
    if (number != index + 1) {
      problems.add('$where: word ${index + 1} is numbered $number');
    }
    if (start < previousEnd || start >= end || end > text.length) {
      problems.add(
        '$where:$number: span [$start, $end) is not after the previous word, '
        'not empty and within ${text.length} code units',
      );
      continue;
    }
    for (final offset in [start, end]) {
      if (_splitsSurrogatePair(text, offset)) {
        problems.add('$where:$number: offset $offset splits a surrogate pair');
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
