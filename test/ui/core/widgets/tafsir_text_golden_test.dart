@Tags(['golden'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/widgets/source_badge.dart';
import 'package:holyquran/ui/core/widgets/tafsir_text.dart';

import '../../../../testing/golden.dart';

void main() {
  testWidgets('tafsir text and its source badge', (tester) async {
    await expectGoldensInThemes(tester, 'tafsir_text', (context) {
      final l10n = AppLocalizations.of(context);
      return SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TafsirText(PackText.fromPack(l10n.sampleLongText)),
            SourceBadge(
              name: PackText.fromPack(l10n.sampleText),
              version: 1,
              onPressed: () {},
            ),
          ],
        ),
      );
    }, surfaceSize: const Size(400, 360));
  });
}
