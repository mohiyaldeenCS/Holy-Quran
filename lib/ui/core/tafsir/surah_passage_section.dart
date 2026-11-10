import 'package:flutter/widgets.dart';

import 'package:holyquran/domain/models/tafsir_surah_passage.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/tafsir_text.dart';

/// A tafsir book's passage on a surah as a whole (D-184), where the surah's
/// tafsir begins: the heading `tafsirAboutSurah` (the owner's wording,
/// 2026-11-10) in the style the tafsir reader heads its lists of books with,
/// then the passage as every passage is drawn. It has no range.
class SurahPassageSection extends StatelessWidget {
  const SurahPassageSection(this.passage, {super.key});

  final TafsirSurahPassage passage;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: AppSpacing.space2,
    children: [
      Semantics(
        header: true,
        child: Text(
          AppLocalizations.of(context).tafsirAboutSurah,
          style: AppTextStyles.bodyStrong.copyWith(
            color: context.colors.inkMuted,
          ),
        ),
      ),
      TafsirText(passage.text),
    ],
  );
}
