@Tags(['golden'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/widgets/continue_card.dart';

import '../../../../testing/golden.dart';

void main() {
  testWidgets('with and without the position line', (tester) async {
    await expectGoldensInThemes(tester, 'continue_card', (context) {
      final l10n = AppLocalizations.of(context);
      final surah = PackText.fromPack(l10n.sampleSurahName);
      return SizedBox(
        width: 380,
        child: goldenColumn([
          ContinueCard(
            surah: surah,
            meta: l10n.sampleMeta,
            progress: 0.07,
            onContinue: () {},
          ),
          ContinueCard(surah: surah, progress: 0.6, onContinue: () {}),
        ]),
      );
    }, surfaceSize: const Size(420, 560));
  });
}
