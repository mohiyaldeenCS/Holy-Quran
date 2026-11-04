import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:holyquran/config/signing_keys.dart';

const _pack = String.fromEnvironment('HOLYQURAN_TEST_PACK');
const _key = String.fromEnvironment('HOLYQURAN_TEST_PACK_KEY');

/// The unapproved test copy this build was made as (D-163), or null in every
/// normal build. Reading it throws in a release build that was given the
/// defines, so `main` reads it before `runApp`. This is the only place the
/// defines are read.
final TestCopy? testCopy = TestCopy.parse(_pack, _key, release: kReleaseMode);

const _idPrefix = 'unapproved-';
final _idPattern = RegExp(r'^[a-z0-9][a-z0-9-]*$');
const _keyLength = 32;

/// The pack a test copy reads from the phone's files, and the throwaway
/// public key its manifest must be signed with.
final class TestCopy {
  const TestCopy._({required this.pack, required this.publicKey});

  final ({String id, int version}) pack;

  /// The raw 32 bytes of an Ed25519 public key.
  final List<int> publicKey;

  /// The test copy [pack], `<id>/<version>`, names, signed by the key [key],
  /// base64 of 32 bytes; null when [pack] is empty, the normal build.
  ///
  /// Throws a [StateError] when [release] is true and a pack is given, when
  /// the id does not begin `unapproved-`, or when the key is one of
  /// [productionKeys]: a pack no one approved is never signed for the
  /// release (D-140 (8)). Throws a [FormatException] when the pack is not
  /// `<id>/<version>` or the key is not base64 of 32 bytes.
  static TestCopy? parse(
    String pack,
    String key, {
    required bool release,
    List<List<int>> productionKeys = manifestPublicKeys,
  }) {
    if (pack.isEmpty) return null;
    if (release) {
      throw StateError(
        'HOLYQURAN_TEST_PACK is set in a release build: the unapproved test '
        'copy is never built for release (D-163).',
      );
    }
    final parts = pack.split('/');
    final version = parts.length == 2 ? int.tryParse(parts[1]) : null;
    if (version == null || version < 1 || !_idPattern.hasMatch(parts[0])) {
      throw FormatException('HOLYQURAN_TEST_PACK is not <id>/<version>', pack);
    }
    if (!parts[0].startsWith(_idPrefix)) {
      throw StateError(
        'The test copy id must begin "$_idPrefix", so that it is never taken '
        'for an approved pack (D-163).',
      );
    }
    final List<int> publicKey;
    try {
      publicKey = base64.decode(key);
    } on FormatException {
      throw const FormatException('HOLYQURAN_TEST_PACK_KEY is not base64');
    }
    if (publicKey.length != _keyLength) {
      throw FormatException(
        'HOLYQURAN_TEST_PACK_KEY is not $_keyLength bytes',
        key,
      );
    }
    for (final production in productionKeys) {
      if (listEquals(production, publicKey)) {
        throw StateError(
          'HOLYQURAN_TEST_PACK_KEY is a production key; the test copy is '
          'signed with a throwaway key only (D-140 (8), D-163).',
        );
      }
    }
    return TestCopy._(
      pack: (id: parts[0], version: version),
      publicKey: List.unmodifiable(publicKey),
    );
  }
}
