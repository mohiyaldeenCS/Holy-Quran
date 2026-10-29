import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/routing/route_table.dart';
import 'package:holyquran/routing/router.dart';
import 'package:holyquran/routing/routes.dart';

void main() {
  final router = createRouter();
  tearDownAll(router.dispose);

  test('finds a screen that has a route', () {
    expect(hasRoute(router, Routes.home), isTrue);
    expect(hasRoute(router, Routes.more), isTrue);
    expect(hasRoute(router, Routes.settings), isTrue);
    expect(hasRoute(router, Routes.resources), isTrue);
    expect(hasRoute(router, Routes.bookmarks), isTrue);
    expect(hasRoute(router, Routes.sources), isTrue);
  });

  test('finds no screen that is not built yet', () {
    expect(hasRoute(router, '/nowhere'), isFalse);
  });
}
