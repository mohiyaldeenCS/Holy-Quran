import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:holyquran/data/repositories/local_pack_repository.dart';
import 'package:holyquran/data/services/manifest_signature.dart';
import 'package:holyquran/data/services/pack_file_service.dart';
import 'package:holyquran/utils/result.dart';
import 'package:path_provider/path_provider.dart';

import 'spike_pack_writer.dart';
import 'tanzil_xml.dart';

const _url = String.fromEnvironment('SPIKE_TANZIL_URL');
const _sha256 = String.fromEnvironment('SPIKE_TANZIL_SHA256');
const _fontAsset = 'assets/fonts/AmiriQuran-Regular.ttf';

/// The largest file accepted; the Uthmani XML is a few megabytes.
const _maxBytes = 32 * 1024 * 1024;

/// On the device: fetches the Tanzil XML from `--dart-define
/// SPIKE_TANZIL_URL`, refuses it unless its SHA-256 is `SPIKE_TANZIL_SHA256`,
/// writes the spike pack under the app support directory and returns the
/// verified pack directory.
Future<String> prepareDeviceTanzilPack() async {
  if (_url.isEmpty || _sha256.isEmpty) {
    throw StateError(
      'SPIKE_TANZIL_URL and SPIKE_TANZIL_SHA256 must be given with '
      '--dart-define',
    );
  }
  final font = await rootBundle.load(_fontAsset);
  return fetchTanzilPack(
    url: Uri.parse(_url),
    expectedSha256: _sha256,
    root: Directory('${(await getApplicationSupportDirectory()).path}/spike'),
    fontBytes: font.buffer.asUint8List(font.offsetInBytes, font.lengthInBytes),
  );
}

/// Fetches [url], checks its SHA-256 against [expectedSha256], converts it
/// with [readTanzilXml] and [writeSpikePack] under [root], replacing an
/// earlier spike pack there, and verifies the result with
/// [LocalPackRepository.verify]. Throws a [StateError] on any refusal,
/// naming digests and addresses only.
Future<String> fetchTanzilPack({
  required Uri url,
  required String expectedSha256,
  required Directory root,
  required Uint8List fontBytes,
  DateTime? now,
}) async {
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(expectedSha256)) {
    throw StateError('the expected SHA-256 is not lowercase hex');
  }
  final bytes = await _fetch(url);
  final found = sha256.convert(bytes).toString();
  if (found != expectedSha256) {
    throw StateError('the file has SHA-256 $found, not $expectedSha256');
  }
  final xml = readTanzilXml(bytes);
  final previous = Directory('${root.path}/$spikePackId');
  if (previous.existsSync()) await previous.delete(recursive: true);
  final date = (now ?? DateTime.now()).toUtc().toIso8601String();
  final directory = await writeSpikePack(
    root,
    surahs: spikeSurahsOf(xml),
    fontSha256: sha256.convert(fontBytes).toString(),
    source: (
      bytes: bytes,
      url: '$url',
      version: tanzilUthmaniVersion,
      fetchedOn: date.substring(0, 10),
      notice: xml.notice,
    ),
  );
  final verified = await const LocalPackRepository(
    files: PackFileService(),
    signatures: SignatureNotConfigured(),
  ).verify(directory);
  if (verified case Failure(:final error)) {
    throw StateError('the spike pack failed verification: $error');
  }
  return directory;
}

Future<Uint8List> _fetch(Uri url) async {
  final client = HttpClient();
  try {
    final response = await (await client.getUrl(url)).close();
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      throw StateError('the server answered ${response.statusCode}');
    }
    final out = BytesBuilder(copy: false);
    await for (final chunk in response) {
      out.add(chunk);
      if (out.length > _maxBytes) {
        throw StateError('the file is larger than $_maxBytes bytes');
      }
    }
    return out.takeBytes();
  } finally {
    client.close(force: true);
  }
}
