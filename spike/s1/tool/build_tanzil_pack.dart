import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:holyquran/data/repositories/local_pack_repository.dart';
import 'package:holyquran/data/services/manifest_signature.dart';
import 'package:holyquran/data/services/pack_file_service.dart';
import 'package:holyquran/utils/result.dart';

import '../text/spike_pack_writer.dart';
import '../text/tanzil_xml.dart';

const _usage =
    'Usage: dart run spike/s1/tool/build_tanzil_pack.dart --input <xml> '
    '--out <dir> [--expected-sha256 <hex>] [--source-url <url>] '
    '[--fetched-on YYYY-MM-DD] [--font <ttf>]\n'
    'Writes <dir>/$spikePackId/$spikePackVersion/. Prints digests, counts and '
    'paths only, never text.';

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

Future<void> main(List<String> arguments) async {
  final options = <String, String>{};
  for (var i = 0; i < arguments.length; i += 2) {
    if (!_options.contains(arguments[i]) || i + 1 >= arguments.length) {
      _exit(64, _usage);
    }
    options[arguments[i]] = arguments[i + 1];
  }
  final input = options['--input'];
  final out = options['--out'];
  if (input == null || out == null) _exit(64, _usage);
  final fetchedOn =
      options['--fetched-on'] ??
      DateTime.now().toUtc().toIso8601String().substring(0, 10);

  final bytes = await File(input).readAsBytes();
  final inputSha256 = sha256.convert(bytes).toString();
  stdout.writeln('input sha256 $inputSha256');
  final expected = options['--expected-sha256'];
  if (expected != null && expected != inputSha256) {
    _exit(65, 'the input is not the file with SHA-256 $expected');
  }

  final String directory;
  try {
    final xml = readTanzilXml(bytes);
    final font = await File(
      options['--font'] ?? 'assets/fonts/AmiriQuran-Regular.ttf',
    ).readAsBytes();
    directory = await writeSpikePack(
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
  } on FormatException catch (e) {
    _exit(65, e.message);
  } on StateError catch (e) {
    _exit(65, e.message);
  }

  final verified = await const LocalPackRepository(
    files: PackFileService(),
    signatures: SignatureNotConfigured(),
  ).verify(directory);
  switch (verified) {
    case Failure(:final error):
      _exit(65, 'the pack failed verification: $error');
    case Ok(value: final pack):
      final counts = pack.manifest.counts;
      stdout
        ..writeln('pack $directory')
        ..writeln(
          'counts surahs ${counts.surahs} ayat ${counts.ayat} '
          'words ${counts.words}',
        )
        ..writeln(
          'divisions ${[for (final MapEntry(:key, :value) in counts.divisions.entries) '${key.name} $value'].join(' ')}',
        )
        ..writeln('text.sqlite sha256 ${pack.manifest.files.single.sha256}')
        ..writeln(
          'manifest.json sha256 '
          '${sha256.convert(await File('$directory/manifest.json').readAsBytes())}',
        );
      for (final MapEntry(:key, :value) in pack.manifest.surahSha256.entries) {
        stdout.writeln('surah $key sha256 $value');
      }
  }
}

Never _exit(int code, String message) {
  stderr.writeln(message);
  exit(code);
}
