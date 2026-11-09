import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/routing/routes.dart';

import '../ui/features/index/index_fixture.dart';
import '../ui/features/search/search_fixture.dart';
import '../ui/features/search/search_harness.dart';
import 'a11y_support.dart';

// The go-to and ayah-context sheets (NV-03, SR-05), over the index pack.
void main() {
  late Directory root;
  late IndexFixture fixture;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('a11y_index_sheets');
    fixture = await IndexFixture.load(root);
  });
  tearDownAll(() async {
    fixture.close();
    await root.delete(recursive: true);
  });

  final sheets = <String, String Function(IndexFixture fixture)>{
    'go to': (_) => Routes.goToSheet,
    'context': (fixture) => Routes.contextSheet(hit(fixture, 1, 2).ayah),
  };

  Future<void> open(
    WidgetTester tester,
    String location,
    Size size,
    double textScale,
  ) async {
    final router = await pumpSearchApp(
      tester,
      fixture,
      search: searchFinding(const []),
      size: size,
      textScale: textScale,
      location: Routes.study,
    );
    unawaited(router.push(location));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
  }

  for (final MapEntry(key: name, value: location) in sheets.entries) {
    for (final view in a11yViews) {
      testWidgets('the $name sheet is accessible: ${view.name}', (
        tester,
      ) async {
        addTearDown(tester.ensureSemantics().dispose);
        await open(tester, location(fixture), view.size, view.textScale);
        await expectAccessible(tester);
      });
    }

    testWidgets('the $name sheet is reached by Tab', (tester) async {
      addTearDown(tester.ensureSemantics().dispose);
      await open(tester, location(fixture), phonePortrait, 1);
      await expectKeyboardReach(tester);
    });
  }
}
