@Tags(['golden'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/widgets/mini_player.dart';

import '../../../../testing/golden.dart';

void main() {
  testWidgets('playing with a repeat count, and paused with no reciter', (
    tester,
  ) async {
    await expectGoldensInThemes(tester, 'mini_player', (context) {
      final l10n = AppLocalizations.of(context);
      final surah = PackText.fromPack(l10n.sampleSurahName);
      return SizedBox(
        width: 380,
        child: goldenColumn([
          MiniPlayer(
            surah: surah,
            ayah: 5,
            reciter: l10n.sampleReciter,
            speed: l10n.gallerySpeed,
            playing: true,
            progress: 0.46,
            repeat: 3,
          ),
          MiniPlayer(
            surah: surah,
            ayah: 255,
            speed: l10n.gallerySpeed,
            playing: false,
            progress: 0.1,
          ),
        ]),
      );
    }, surfaceSize: const Size(420, 520));
  });
}
