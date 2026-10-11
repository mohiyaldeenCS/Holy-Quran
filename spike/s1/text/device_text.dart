import 'dart:async';
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
const _packSha256 = String.fromEnvironment('SPIKE_TANZIL_PACK_SHA256');
const _fontAsset = 'assets/fonts/AmiriQuran-Regular.ttf';

/// The largest file accepted; the Uthmani XML is a few megabytes.
const _maxBytes = 32 * 1024 * 1024;

const _connectionTimeout = Duration(seconds: 20);

/// On the device: fetches the Tanzil XML from `--dart-define
/// SPIKE_TANZIL_URL`, refuses it unless its SHA-256 is `SPIKE_TANZIL_SHA256`,
/// writes the spike pack under the app support directory, refuses it unless
/// its text.sqlite has the SHA-256 the CI run recorded,
/// `SPIKE_TANZIL_PACK_SHA256`, and returns the verified pack directory.
Future<String> prepareDeviceTanzilPack() async {
  if (_url.isEmpty || _sha256.isEmpty || _packSha256.isEmpty) {
    throw StateError(
      'SPIKE_TANZIL_URL, SPIKE_TANZIL_SHA256 and SPIKE_TANZIL_PACK_SHA256 '
      'must all be given with --dart-define',
    );
  }
  final font = await rootBundle.load(_fontAsset);
  return fetchTanzilPack(
    url: Uri.parse(_url),
    expectedSha256: _sha256,
    expectedPackSha256: _packSha256,
    root: Directory('${(await getApplicationSupportDirectory()).path}/spike'),
    fontBytes: font.buffer.asUint8List(font.offsetInBytes, font.lengthInBytes),
  );
}

/// Fetches [url], checks its SHA-256 against [expectedSha256], converts it
/// with [readTanzilXml] and [writeSpikePack] under [root], replacing an
/// earlier spike pack there, verifies the result with
/// [LocalPackRepository.verify] and requires its text.sqlite to have the
/// SHA-256 [expectedPackSha256]; text.sqlite holds no date, so the fetch
/// date does not change it. The fetch gives up after [timeout] in all, or
/// when no connection is made within 20 seconds.
///
/// Every refusal is a [StateError], or the reader's [FormatException],
/// naming digests, addresses or an exception type only; no other
/// exception's text escapes, since it might hold Quran text (D-072).
Future<String> fetchTanzilPack({
  required Uri url,
  required String expectedSha256,
  required String expectedPackSha256,
  required Directory root,
  required Uint8List fontBytes,
  DateTime? now,
  Duration timeout = const Duration(minutes: 3),
}) async {
  for (final hash in [expectedSha256, expectedPackSha256]) {
    if (!_hex.hasMatch(hash)) {
      throw StateError('an expected SHA-256 is not lowercase hex');
    }
  }
  var step = 'fetching';
  try {
    final bytes = await _fetch(url, timeout);
    final found = sha256.convert(bytes).toString();
    if (found != expectedSha256) {
      throw StateError('the file has SHA-256 $found, not $expectedSha256');
    }
    step = 'reading';
    final xml = readTanzilXml(bytes);
    step = 'writing';
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
    step = 'verifying';
    final verified = await const LocalPackRepository(
      files: PackFileService(),
      signatures: SignatureNotConfigured(),
    ).verify(directory);
    switch (verified) {
      case Failure(:final error):
        throw StateError('the spike pack failed verification: $error');
      case Ok(:final value)
          when value.manifest.files.single.sha256 != expectedPackSha256:
        await previous.delete(recursive: true);
        throw StateError(
          'the device pack text.sqlite has SHA-256 '
          '${value.manifest.files.single.sha256}, not $expectedPackSha256',
        );
      case Ok():
    }
    return directory;
  } on StateError {
    rethrow;
  } on FormatException catch (e) {
    throw FormatException(e.message);
  } on Object catch (e) {
    throw StateError('$step: ${e.runtimeType}');
  }
}

final _hex = RegExp(r'^[0-9a-f]{64}$');

/// The file's own bytes: identity encoding is asked for, and a gzip answer
/// is uncompressed here, so the SHA-256 pin is checked on the file either
/// way; any other encoding is refused. At most [_maxBytes] are accepted
/// after uncompressing. After [timeout] the connection is closed and a
/// [TimeoutException] thrown.
Future<Uint8List> _fetch(Uri url, Duration timeout) async {
  final client = HttpClient()
    ..connectionTimeout = _connectionTimeout
    ..autoUncompress = false;
  var timedOut = false;
  final timer = Timer(timeout, () {
    timedOut = true;
    client.close(force: true);
  });
  try {
    final request = await client.getUrl(url);
    request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      throw StateError('the server answered ${response.statusCode}');
    }
    final encoding = response.headers
        .value(HttpHeaders.contentEncodingHeader)
        ?.trim()
        .toLowerCase();
    if (encoding != null && encoding != 'identity' && encoding != 'gzip') {
      await response.drain<void>();
      throw StateError(
        'the server sent a Content-Encoding other than identity or gzip',
      );
    }
    final body = encoding == 'gzip'
        ? response.transform(gzip.decoder)
        : response;
    final out = BytesBuilder(copy: false);
    await for (final chunk in body) {
      out.add(chunk);
      if (out.length > _maxBytes) {
        throw StateError('the file is larger than $_maxBytes bytes');
      }
    }
    return out.takeBytes();
  } on Object {
    if (timedOut) throw TimeoutException(null, timeout);
    rethrow;
  } finally {
    timer.cancel();
    client.close(force: true);
  }
}
