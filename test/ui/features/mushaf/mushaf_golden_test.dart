@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/ui/features/mushaf/view_models/mushaf_view_model.dart';

import '../../../../testing/fakes/fake_player_repository.dart';
import 'mushaf_harness.dart';
import 'recitation_fixture.dart';

// The reader on the phone of the Screens board (390 wide), opened in the long
// synthetic surah, in each theme: as drawn, at 200% system text, with
// everything but the text hidden, without a verified pack, and following a
// recitation that the user scrolled away from: the ayah recited, with its
// marker filled, and «عُد إلى موضع التلاوة».
const _phone = Size(390, 844);

void main() {
  late Directory root;
  late MushafRig rig;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('mushaf_golden');
    rig = await MushafRig.load(root);
  });
  tearDownAll(() async {
    rig.close();
    await root.delete(recursive: true);
  });

  Future<void> expectReader(
    WidgetTester tester,
    String name,
    ReadingTheme theme, {
    double textScale = 1,
    bool distractionFree = false,
    bool verified = true,
    bool recited = false,
    bool following = false,
    bool stand = false,
  }) async {
    setReaderView(tester, _phone);
    final player = FakePlayerRepository();
    final viewModel = verified
        ? rig.viewModel(address: QuranAddress('hafs', 2, 1), player: player)
        : MushafViewModel();
    addTearDown(viewModel.dispose);
    await tester.pumpWidget(
      readerApp(viewModel, theme: theme, textScale: textScale, size: _phone),
    );
    await tester.pumpAndSettle();
    viewModel.setDistractionFree(distractionFree);
    if (following || stand) {
      player.reach(recitationPlan(), ayahSegment(2, 3));
      await tester.pumpAndSettle();
      viewModel.setStandMode(stand);
    }
    if (recited) {
      player.reach(recitationPlan(), ayahSegment(2, 3));
      await tester.pumpAndSettle();
      viewModel.follow.userScrolled();
    }
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(WidgetsApp),
      matchesGoldenFile('goldens/mushaf_${name}_${theme.name}.png'),
    );
  }

  for (final theme in ReadingTheme.values) {
    testWidgets('the reader in ${theme.name}', (tester) async {
      await expectReader(tester, 'reader', theme);
    });

    testWidgets('the reader at 200% in ${theme.name}', (tester) async {
      await expectReader(tester, 'reader_200', theme, textScale: 2);
    });

    testWidgets('the reader without distraction in ${theme.name}', (
      tester,
    ) async {
      await expectReader(tester, 'reader_free', theme, distractionFree: true);
    });

    testWidgets('the reader following a recitation in ${theme.name}', (
      tester,
    ) async {
      await expectReader(tester, 'reader_following', theme, following: true);
    });

    testWidgets('the reader in stand mode in ${theme.name}', (tester) async {
      await expectReader(tester, 'reader_stand', theme, stand: true);
    });

    for (final scale in [1.0, 2.0]) {
      testWidgets('the reader following a recitation at ${scale * 100}% in '
          '${theme.name}', (tester) async {
        await expectReader(
          tester,
          scale == 1 ? 'reader_recited' : 'reader_recited_200',
          theme,
          textScale: scale,
          recited: true,
        );
      });
    }

    testWidgets('the reader without a verified pack in ${theme.name}', (
      tester,
    ) async {
      await expectReader(tester, 'reader_unavailable', theme, verified: false);
    });
  }
}
