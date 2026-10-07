import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/routing/router.dart';
import 'package:holyquran/ui/core/app.dart';
import 'package:holyquran/ui/features/home/views/home_screen.dart';

void main() {
  testWidgets('starts in Arabic, right to left', (tester) async {
    await tester.pumpWidget(QuranApp(router: createRouter()));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(HomeScreen));
    expect(Localizations.localeOf(context), const Locale('ar'));
    expect(Directionality.of(context), TextDirection.rtl);
  });

  testWidgets('the window title is the localized app name', (tester) async {
    await tester.pumpWidget(QuranApp(router: createRouter()));
    await tester.pumpAndSettle();

    final title = tester.widget<Title>(find.byType(Title)).title;
    expect(title, lookupAppLocalizations(const Locale('ar')).appTitle);
  });
}
