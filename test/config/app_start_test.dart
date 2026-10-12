import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/main.dart' as app;
import 'package:holyquran/ui/core/widgets/splash.dart';
import 'package:holyquran/ui/features/home/views/home_screen.dart';
import 'package:provider/single_child_widget.dart';

void main() {
  testWidgets('shows the splash until the dependencies are built', (
    tester,
  ) async {
    final dependencies = Completer<List<SingleChildWidget>>();
    await tester.pumpWidget(app.AppStart(dependencies: dependencies.future));

    expect(find.byType(Splash), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);

    dependencies.complete(const []);
    await tester.pumpAndSettle();

    expect(find.byType(Splash), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
    final context = tester.element(find.byType(HomeScreen));
    expect(Localizations.localeOf(context), const Locale('ar'));
    expect(Directionality.of(context), TextDirection.rtl);
  });

  testWidgets('the splash is in Arabic, right to left', (tester) async {
    await tester.pumpWidget(
      app.AppStart(dependencies: Completer<List<SingleChildWidget>>().future),
    );

    final context = tester.element(find.byType(Splash));
    expect(Localizations.localeOf(context), const Locale('ar'));
    expect(Directionality.of(context), TextDirection.rtl);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed start is reported and keeps the splash', (
    tester,
  ) async {
    final dependencies = Completer<List<SingleChildWidget>>();
    await tester.pumpWidget(app.AppStart(dependencies: dependencies.future));

    dependencies.completeError(StateError('synthetic'));
    await tester.pump();

    expect(tester.takeException(), isStateError);
    expect(find.byType(Splash), findsOneWidget);
  });

  testWidgets('main starts the app on the home tab', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
