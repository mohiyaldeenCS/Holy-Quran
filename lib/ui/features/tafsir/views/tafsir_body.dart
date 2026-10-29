import 'package:flutter/widgets.dart' hide Icon;

import 'package:holyquran/domain/models/pack_failure.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/tafsir/source_details_sheet.dart';
import 'package:holyquran/ui/core/tafsir/tafsir_page.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/ayah_row.dart';
import 'package:holyquran/ui/core/widgets/button.dart';
import 'package:holyquran/ui/core/widgets/icon_button.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/core/widgets/integrity_alert.dart';
import 'package:holyquran/ui/core/widgets/source_badge.dart';
import 'package:holyquran/ui/core/widgets/surah_name.dart';
import 'package:holyquran/ui/core/widgets/tafsir_text.dart';
import 'package:holyquran/ui/features/tafsir/view_models/tafsir_view_model.dart';

/// What the tafsir reader and the tafsir sheet show for an ayah (`TF-03`,
/// `TF-04`): the ayah above, the range the passage explains when it is more
/// than one ayah, the passage, and the source badge with the copy button
/// beneath it. An ayah the book has no passage for shows the fixed sentence
/// (D-033); with no book downloaded, the book's absence and, while the
/// catalogue offers one, the way to the download.
class TafsirBody extends StatelessWidget {
  const TafsirBody({
    required this.viewModel,
    required this.onOfferDownload,
    super.key,
  });

  final TafsirViewModel viewModel;

  /// Opens the offer of the first download (`TF-06`); null when there is
  /// nothing to open, and the offer is then not shown.
  final VoidCallback? onOfferDownload;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final surahName = viewModel.surahName;
    final ayahText = viewModel.ayahText;
    final page = viewModel.page;
    final failure = viewModel.failure;
    final muted = AppTextStyles.body.copyWith(color: colors.inkMuted);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.space4,
      children: [
        if (surahName != null)
          SurahName(
            surahName,
            format: SurahNameFormat.titled,
            style: AppTextStyles.secondary.copyWith(color: colors.inkMuted),
          ),
        if (ayahText != null)
          AyahRow(number: viewModel.address.ayah, text: ayahText),
        if (!viewModel.hasTafsirs) ...[
          Text(l10n.noTafsirsYet, style: muted),
          if (viewModel.available.isNotEmpty && onOfferDownload != null)
            Button(
              label: l10n.resourceDownload,
              variant: ButtonVariant.tonal,
              onPressed: onOfferDownload,
            ),
        ] else if (failure is PackFailure && failure is! AddressNotInPack)
          IntegrityAlert(
            title: l10n.integrityPackTitle,
            body: l10n.integrityPackBody,
          )
        else if (page != null)
          ..._passage(context, page, muted),
      ],
    );
  }

  List<Widget> _passage(
    BuildContext context,
    TafsirPage page,
    TextStyle muted,
  ) {
    final l10n = AppLocalizations.of(context);
    final passage = page.passage;
    final range = page.range;
    return [
      if (range != null)
        Text(
          l10n.tafsirRange(arabicDigits(range.first), arabicDigits(range.last)),
          style: AppTextStyles.secondary.copyWith(
            color: context.colors.inkMuted,
          ),
        ),
      if (passage != null)
        TafsirText(passage.text)
      else
        Text(l10n.tafsirNoPassage, style: muted),
      Row(
        spacing: AppSpacing.space2,
        children: [
          Expanded(
            child: SourceBadge(
              name: page.book.title,
              version: page.version,
              onPressed: () => showSourceDetails(context, page),
            ),
          ),
          if (passage != null && viewModel.canCopy)
            IconButton(
              icon: IconName.copy,
              label: l10n.toolbarCopy,
              tone: IconButtonTone.tint,
              onPressed: viewModel.copy.execute,
            ),
        ],
      ),
    ];
  }
}
