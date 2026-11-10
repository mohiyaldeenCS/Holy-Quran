import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/pack_failure.dart';
import 'package:holyquran/domain/models/pack_integrity.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/widgets/continue_card.dart';
import 'package:holyquran/ui/core/widgets/integrity_alert.dart';
import 'package:holyquran/ui/features/home/view_models/home_view_model.dart';

import '../../../../../testing/fakes/fake_pack_integrity_repository.dart';
import '../../../../../testing/fakes/fake_reading_position_repository.dart';
import '../home_harness.dart';

// D-180: home says that a missing base pack is missing, from the first
// start, and keeps saying that a failed one failed.
final _l10n = lookupAppLocalizations(const Locale('ar'));

void _expectMissingAlert() {
  expect(find.byType(IntegrityAlert), findsOneWidget);
  expect(find.text(_l10n.integrityBaseMissingTitle), findsOneWidget);
  expect(find.text(_l10n.integrityBaseMissingBody), findsOneWidget);
  expect(find.text(_l10n.integrityBaseTitle), findsNothing);
  expect(find.text(_l10n.integrityBaseBody), findsNothing);
  expect(find.text(_l10n.homeContinueHint), findsNothing);
}

bool _isLiveRegion(Widget widget) =>
    widget is Semantics && widget.properties.liveRegion == true;

void main() {
  testWidgets('at the first start, with nothing reported yet, a missing pack '
      'shows the missing alert', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpHomeScreen(
      tester,
      HomeViewModel(
        positions: FakeReadingPositionRepository(),
        integrity: FakePackIntegrityRepository(),
        basePackId: 'base',
      ),
    );

    _expectMissingAlert();
    expect(
      find.ancestor(
        of: find.byType(IntegrityAlert),
        matching: find.byWidgetPredicate(_isLiveRegion),
      ),
      findsWidgets,
    );
    expect(
      tester.getSemantics(find.byType(IntegrityAlert)).label,
      allOf(
        contains(_l10n.integrityBaseMissingTitle),
        contains(_l10n.integrityBaseMissingBody),
      ),
    );
    expect(find.byType(ContinueCard), findsNothing);
    handle.dispose();
  });

  testWidgets('a pack reported missing shows the missing alert', (
    tester,
  ) async {
    await pumpHomeScreen(
      tester,
      HomeViewModel(
        integrity: FakePackIntegrityRepository({
          'base': const IntegrityMissing(),
        }),
        basePackId: 'base',
      ),
    );

    _expectMissingAlert();
  });

  testWidgets('a pack that goes missing after a start shows the missing '
      'alert', (tester) async {
    final integrity = FakePackIntegrityRepository({
      'base': const IntegrityOk(),
    });
    await pumpHomeScreen(
      tester,
      HomeViewModel(integrity: integrity, basePackId: 'base'),
    );
    expect(find.byType(IntegrityAlert), findsNothing);

    integrity.report('base', const IntegrityMissing());
    await tester.pumpAndSettle();

    _expectMissingAlert();
  });

  testWidgets('a failed pack keeps the failed alert', (tester) async {
    await pumpHomeScreen(
      tester,
      HomeViewModel(
        integrity: FakePackIntegrityRepository({
          'base': const IntegrityFailed(PackInconsistent('base', 'synthetic')),
        }),
        basePackId: 'base',
      ),
    );

    expect(find.text(_l10n.integrityBaseTitle), findsOneWidget);
    expect(find.text(_l10n.integrityBaseBody), findsOneWidget);
    expect(find.text(_l10n.integrityBaseMissingTitle), findsNothing);
    expect(find.text(_l10n.integrityBaseMissingBody), findsNothing);
  });

  testWidgets('a pack being repaired shows no alert, as before', (
    tester,
  ) async {
    await pumpHomeScreen(
      tester,
      HomeViewModel(
        integrity: FakePackIntegrityRepository({
          'base': const IntegrityRepairing(),
        }),
        basePackId: 'base',
      ),
    );

    expect(find.byType(IntegrityAlert), findsNothing);
    expect(find.text(_l10n.homeContinueHint), findsOneWidget);
  });

  for (final theme in ReadingTheme.values) {
    testWidgets('the missing alert lays out in ${theme.name} at 200%', (
      tester,
    ) async {
      await pumpHomeScreen(
        tester,
        HomeViewModel(
          integrity: FakePackIntegrityRepository(),
          basePackId: 'base',
        ),
        theme: theme,
        textScale: 2,
      );

      expect(tester.takeException(), isNull);
      expect(find.text(_l10n.integrityBaseMissingTitle), findsOneWidget);
    });
  }
}
