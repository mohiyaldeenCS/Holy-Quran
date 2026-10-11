import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:holyquran/data/repositories/local_pack_repository.dart';
import 'package:holyquran/data/repositories/pack_quran_text_repository.dart';
import 'package:holyquran/data/services/manifest_signature.dart';
import 'package:holyquran/data/services/pack_file_service.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/verified_pack.dart';
import 'package:holyquran/utils/result.dart';

import '../text/spike_pack_writer.dart';
import '../text/tanzil_xml.dart';

const _usage =
    'Usage: dart run spike/s1/tool/build_tanzil_pack.dart --input <xml> '
    '--out <dir> [--expected-sha256 <hex>] [--source-url <url>] '
    '[--fetched-on YYYY-MM-DD] [--font <ttf>]\n'
    'Writes <dir>/$spikePackId/$spikePackVersion/. Prints digests, counts, '
    'options, code points and paths only, never text.';

const _options = {
  '--input',
  '--out',
  '--expected-sha256',
  '--source-url',
  '--fetched-on',
  '--font',
};

/// The source URL of docs/SOURCES.md, row 1, unless `--source-url` names the
/// download.
const _registryUrl = 'https://tanzil.net/docs/tanzil_project';

/// Prints only messages this tool or the spike code wrote; any other
/// exception by its type alone, since its text might hold Quran text (D-072).
Future<void> main(List<String> arguments) async {
  var code = 0;
  try {
    await _run(arguments);
  } on _Exit catch (e) {
    stderr.writeln(e.message);
    code = e.code;
  } on FormatException catch (e) {
    stderr.writeln(e.message);
    code = 65;
  } on StateError catch (e) {
    stderr.writeln(e.message);
    code = 65;
  } on Object catch (e) {
    stderr.writeln('failed: ${e.runtimeType}');
    code = 70;
  }
  await stdout.flush();
  await stderr.flush();
  exit(code);
}

final class _Exit implements Exception {
  const _Exit(this.code, this.message);

  final int code;
  final String message;
}

Future<void> _run(List<String> arguments) async {
  final options = <String, String>{};
  for (var i = 0; i < arguments.length; i += 2) {
    if (!_options.contains(arguments[i]) || i + 1 >= arguments.length) {
      throw const _Exit(64, _usage);
    }
    options[arguments[i]] = arguments[i + 1];
  }
  final input = options['--input'];
  final out = options['--out'];
  if (input == null || out == null) throw const _Exit(64, _usage);
  final fetchedOn =
      options['--fetched-on'] ??
      DateTime.now().toUtc().toIso8601String().substring(0, 10);

  final bytes = await File(input).readAsBytes();
  final inputSha256 = sha256.convert(bytes).toString();
  stdout.writeln('input sha256 $inputSha256');
  final expected = options['--expected-sha256'];
  if (expected != null && expected != inputSha256) {
    throw _Exit(65, 'the input is not the file with SHA-256 $expected');
  }

  final xml = readTanzilXml(bytes);
  final font = await File(
    options['--font'] ?? 'assets/fonts/AmiriQuran-Regular.ttf',
  ).readAsBytes();
  final directory = await writeSpikePack(
    Directory(out),
    surahs: spikeSurahsOf(xml),
    fontSha256: sha256.convert(font).toString(),
    source: (
      bytes: bytes,
      url: options['--source-url'] ?? _registryUrl,
      version: tanzilUthmaniVersion,
      fetchedOn: fetchedOn,
      notice: xml.notice,
    ),
  );

  final verified = await const LocalPackRepository(
    files: PackFileService(),
    signatures: SignatureNotConfigured(),
  ).verify(directory);
  switch (verified) {
    case Failure(:final error):
      throw _Exit(65, 'the pack failed verification: $error');
    case Ok(value: final pack):
      final counts = pack.manifest.counts;
      final divisions = [
        for (final MapEntry(:key, :value) in counts.divisions.entries)
          '${key.name} $value',
      ];
      final manifest = await File('$directory/manifest.json').readAsBytes();
      final options = pack.manifest.sources.single.options;
      final marks = await _markCodePoints(pack);
      stdout
        ..writeln('pack $directory')
        ..writeln(
          'counts surahs ${counts.surahs} ayat ${counts.ayat} '
          'words ${counts.words} marks ${counts.marks}',
        )
        ..writeln('divisions ${divisions.join(' ')}')
        ..writeln('options ${_optionsLine(options)}')
        ..writeln('mark code point sets ${marks.length}');
      for (final (set, count) in marks) {
        stdout.writeln('$set $count');
      }
      stdout
        ..writeln('text.sqlite sha256 ${pack.manifest.files.single.sha256}')
        ..writeln('manifest.json sha256 ${sha256.convert(manifest)}');
      for (final MapEntry(:key, :value) in pack.manifest.surahSha256.entries) {
        stdout.writeln('surah $key sha256 $value');
      }
  }
}

/// The marks of [pack] by the set of code points each holds, named
/// `U+XXXX` in ascending order, with their counts, most frequent first. The
/// marks are read by address and sliced at their stored offsets.
Future<List<(String, int)>> _markCodePoints(VerifiedPack pack) async {
  final text = switch (PackQuranTextRepository.open(pack)) {
    Ok(:final value) => value,
    Failure(:final error) => throw _Exit(65, 'the pack failed to open: $error'),
  };
  T expectOk<T>(Result<T> result) => switch (result) {
    Ok(:final value) => value,
    Failure(:final error) => throw _Exit(65, 'reading the pack: $error'),
  };
  final counts = <String, int>{};
  try {
    for (final surah in expectOk(await text.surahs())) {
      for (var ayah = 1; ayah <= surah.ayahCount; ayah++) {
        final address = QuranAddress(text.riwaya, surah.number, ayah);
        final value = expectOk(await text.ayahText(address)).verbatim;
        for (final mark in expectOk(await text.marks(address))) {
          final codePoints = value.substring(mark.start, mark.end).runes;
          final key = (codePoints.toSet().toList()..sort())
              .map(spikeCodePointName)
              .join(' ');
          counts[key] = (counts[key] ?? 0) + 1;
        }
      }
    }
  } finally {
    text.close();
  }
  return [
    for (final MapEntry(:key, :value) in counts.entries) (key, value),
  ]..sort((a, b) => a.$2 != b.$2 ? b.$2.compareTo(a.$2) : a.$1.compareTo(b.$1));
}

String _optionsLine(Map<String, Object>? options) => options == null
    ? 'none'
    : [
        for (final MapEntry(:key, :value) in options.entries)
          '${_ascii(key)}=${_ascii('$value')}',
      ].join(' ');

/// [value] with every code point outside printable ASCII, and `=`, named
/// `U+XXXX`, so the output stays ASCII.
String _ascii(String value) => [
  for (final c in value.runes)
    c >= 0x21 && c <= 0x7E && c != 0x3D
        ? String.fromCharCode(c)
        : spikeCodePointName(c),
].join();
