@Tags(['golden'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/widgets/reader_player_bar.dart';

import '../../../../testing/golden.dart';

void main() {
  testWidgets('playing with the reciter, and paused without', (tester) async {
    await expectGoldensInThemes(tester, 'reader_player_bar', (context) {
      final l10n = AppLocalizations.of(context);
      final surah = PackText.fromPack(l10n.sampleSurahName);
      // Screens.dc.html draws the bar 358 wide: 390 less 16 on each side.
      return SizedBox(
        width: 358,
        child: goldenColumn([
          ReaderPlayerBar(
            surah: surah,
            ayah: 4,
            reciter: l10n.sampleReciter,
            playing: true,
          ),
          ReaderPlayerBar(surah: surah, ayah: 4, playing: false),
        ]),
      );
    }, surfaceSize: const Size(400, 240));
  });
}
