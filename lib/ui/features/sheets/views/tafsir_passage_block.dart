import 'package:flutter/widgets.dart';

import 'package:holyquran/domain/models/pack_failure.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/tafsir/source_details_sheet.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/integrity_alert.dart';
import 'package:holyquran/ui/core/widgets/source_badge.dart';
import 'package:holyquran/ui/core/widgets/tafsir_text.dart';
import 'package:holyquran/ui/features/sheets/view_models/ayah_tafsir.dart';

/// The tafsir of an ayah inside a sheet that carries more than the tafsir
/// (`TF-04`, `TF-05`, `LX-11`): the range the passage explains when it is
/// more than one ayah, the passage, and the source badge, whose press opens
/// the book's details. An ayah the book has no passage for shows the fixed
/// sentence of the `TF` criteria; a pack that failed its checks shows the
/// integrity alert instead of its content. Nothing shows while the passage
/// is unread, or when it cannot be read for another reason.
class TafsirPassageBlock extends StatelessWidget {
  const TafsirPassageBlock({required this.tafsir, super.key});

  final AyahTafsir tafsir;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: tafsir,
    builder: (context, _) {
      final l10n = AppLocalizations.of(context);
      final colors = context.colors;
      final failure = tafsir.failure;
      if (failure is PackFailure && failure is! AddressNotInPack) {
        return IntegrityAlert(
          title: l10n.integrityPackTitle,
          body: l10n.integrityPackBody,
        );
      }
      final page = tafsir.page;
      if (page == null) return const SizedBox.shrink();
      final passage = page.passage;
      final range = page.range;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.space3,
        children: [
          if (range != null)
            Text(
              l10n.tafsirRange(
                arabicDigits(range.first),
                arabicDigits(range.last),
              ),
              style: AppTextStyles.secondary.copyWith(color: colors.inkMuted),
            ),
          if (passage != null)
            TafsirText(passage.text)
          else
            Text(
              l10n.tafsirNoPassage,
              style: AppTextStyles.body.copyWith(color: colors.inkMuted),
            ),
          SourceBadge(
            name: page.book.title,
            version: page.version,
            onPressed: () => showSourceDetails(context, page),
          ),
        ],
      );
    },
  );
}
