import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/utils/result.dart';

String _describe(Result<int> result) => switch (result) {
  Ok(:final value) => 'ok $value',
  Failure(:final error) => 'failed $error',
};

void main() {
  test('Ok carries its value', () {
    const Result<int> result = Ok(7);
    expect((result as Ok<int>).value, 7);
    expect(_describe(result), 'ok 7');
  });

  test('Failure carries its exception', () {
    const error = FormatException('synthetic');
    const Result<int> result = Failure(error);
    expect((result as Failure<int>).error, same(error));
    expect(_describe(result), 'failed $error');
  });

  test('Ok may carry null for a nullable type', () {
    const Result<int?> result = Ok(null);
    expect(switch (result) {
      Ok(:final value) => value,
      Failure() => -1,
    }, isNull);
  });
}
