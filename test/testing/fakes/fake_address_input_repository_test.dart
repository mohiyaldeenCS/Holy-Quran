import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/utils/result.dart';

import '../../../testing/fakes/fake_address_input_repository.dart';

final class _Failed implements Exception {
  const _Failed();
}

Object? _value(Result<int?> result) => switch (result) {
  Ok(:final value) => value,
  Failure(:final error) => error,
};

void main() {
  test('answers from its names and records each lookup', () async {
    final fake = FakeAddressInputRepository(names: {'Synthetic one': 1});
    expect(_value(await fake.surahNamed('Synthetic one')), 1);
    expect(_value(await fake.surahNamed('other')), isNull);
    expect(fake.lookups, ['Synthetic one', 'other']);
  });

  test('fails every lookup while a failure is set', () async {
    final fake = FakeAddressInputRepository(
      names: {'Synthetic one': 1},
      failure: const _Failed(),
    );
    expect(_value(await fake.surahNamed('Synthetic one')), const _Failed());
    fake.failure = null;
    expect(_value(await fake.surahNamed('Synthetic one')), 1);
  });
}
