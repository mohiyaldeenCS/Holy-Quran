import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/utils/result.dart';

import '../../../testing/fakes/fake_search_history_repository.dart';

void main() {
  test('records newest first, moves repeats up and clears', () async {
    final history = FakeSearchHistoryRepository(['query-a']);

    await history.record('query-b');
    await history.record('query-a');
    await history.record('');
    expect((await history.queries() as Ok<List<String>>).value, [
      'query-a',
      'query-b',
    ]);

    await history.clear();
    expect((await history.queries() as Ok<List<String>>).value, isEmpty);
  });
}
