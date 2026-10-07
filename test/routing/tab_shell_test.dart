import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/routing/router.dart';
import 'package:holyquran/ui/core/app.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('ar'));

  testWidgets('the tab bar is named for screen readers', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(QuranApp(router: createRouter()));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel(l10n.mainNavigationLabel), findsOneWidget);
    for (final label in [
      l10n.tabHome,
      l10n.tabMushaf,
      l10n.tabListen,
      l10n.tabStudy,
      l10n.tabMore,
    ]) {
      expect(
        find.bySemanticsLabel(RegExp(RegExp.escape(label))),
        findsWidgets,
        reason: label,
      );
    }
    semantics.dispose();
  });

  testWidgets('every tab has a labelled hit area of at least 48', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(QuranApp(router: createRouter()));
    await tester.pumpAndSettle();

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });
}
