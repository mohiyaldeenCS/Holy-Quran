import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/config/signing_keys.dart';
import 'package:holyquran/config/test_copy.dart';

final _key = base64.encode(List.generate(32, (i) => i + 1));

void main() {
  test('is null with no define, in release too', () {
    expect(TestCopy.parse('', '', release: false), isNull);
    expect(TestCopy.parse('', '', release: true), isNull);
    expect(TestCopy.parse('', _key, release: true), isNull);
  });

  test('reads the pack and the key of a debug or profile build', () {
    final copy = TestCopy.parse(
      'unapproved-synthetic/2',
      _key,
      release: false,
    )!;
    expect(copy.pack, (id: 'unapproved-synthetic', version: 2));
    expect(copy.publicKey, List.generate(32, (i) => i + 1));
  });

  test('refuses a pack in a release build', () {
    expect(
      () => TestCopy.parse('unapproved-synthetic/1', _key, release: true),
      throwsStateError,
    );
    expect(() => TestCopy.parse('hafs/1', '', release: true), throwsStateError);
  });

  test('refuses an id that does not begin unapproved-', () {
    for (final pack in ['hafs/1', 'synthetic-unapproved-x/1']) {
      expect(
        () => TestCopy.parse(pack, _key, release: false),
        throwsStateError,
        reason: pack,
      );
    }
  });

  test('refuses a pack that is not <id>/<version>', () {
    for (final pack in [
      'unapproved-x',
      'unapproved-x/',
      'unapproved-x/0',
      'unapproved-x/-1',
      'unapproved-x/one',
      'unapproved-x/1/2',
      'unapproved-../1',
      'unapproved-X/1',
      '/1',
    ]) {
      expect(
        () => TestCopy.parse(pack, _key, release: false),
        throwsFormatException,
        reason: pack,
      );
    }
  });

  test('refuses a key that is not base64 of 32 bytes', () {
    for (final key in [
      '',
      'not base64!',
      base64.encode(List.filled(31, 1)),
      base64.encode(List.filled(33, 1)),
      base64.encode(List.filled(64, 1)),
    ]) {
      expect(
        () => TestCopy.parse('unapproved-x/1', key, release: false),
        throwsFormatException,
        reason: key,
      );
    }
  });

  test('refuses a production key, the key in use or the spare', () {
    final production = [List.generate(32, (i) => i + 1), List.filled(32, 9)];
    for (final key in production) {
      expect(
        () => TestCopy.parse(
          'unapproved-x/1',
          base64.encode(key),
          release: false,
          productionKeys: production,
        ),
        throwsStateError,
      );
    }
    expect(
      TestCopy.parse(
        'unapproved-x/1',
        base64.encode(List.filled(32, 7)),
        release: false,
        productionKeys: production,
      ),
      isNotNull,
    );
  });

  test('takes the production keys of signing_keys.dart by default', () {
    for (final key in manifestPublicKeys) {
      expect(
        () => TestCopy.parse(
          'unapproved-x/1',
          base64.encode(key),
          release: false,
        ),
        throwsStateError,
      );
    }
  });

  test('this test run is not a test copy', () {
    expect(testCopy, isNull);
  });
}
