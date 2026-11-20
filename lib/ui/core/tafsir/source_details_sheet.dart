import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/routing/route_table.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/routing/routes/sheet_page.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/tafsir/tafsir_page.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/button.dart';
import 'package:holyquran/ui/core/widgets/copy_sheet.dart';
import 'package:holyquran/ui/core/widgets/tafsir_text.dart';

/// Opens the details of the source behind [page] over the current screen
/// (`TF-05`): a sheet, as PRD §7.7 has the source badge open.
Future<void> showSourceDetails(BuildContext context, TafsirPage page) =>
    Navigator.of(context, rootNavigator: true).push<void>(
      SheetPage<void>(child: SourceDetailsSheet(page: page))
          .createRoute(context),
    );

/// The facts of a tafsir book (`TF-05`): its title, then its author, its
/// edition and editor, the source it was digitised from and its version. A
/// fact the source does not give is left out. «أبلغ عن خطأ» on the ayah and
/// its pack ends it while the report sheet has a route (D-127).
class SourceDetailsSheet extends StatelessWidget {
  const SourceDetailsSheet({required this.page, super.key});

  final TafsirPage page;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final book = page.book;
    final value = AppTextStyles.body.copyWith(color: colors.ink);
    final router = GoRouter.maybeOf(context);
    final report = Routes.reportSheet(page.position.ayah, pack: page.packId);
    return CopySheetFrame(
      children: [
        Semantics(
          header: true,
          child: TafsirText(book.title, style: AppTextStyles.sectionTitle),
        ),
        _Fact(
          label: l10n.sourceAuthor,
          value: TafsirText(book.author, style: AppTextStyles.body),
        ),
        for (final text in [book.edition, book.editor])
          if (text != null)
            _Fact(
              label: l10n.sourceEditionOrEditor,
              value: TafsirText(text, style: AppTextStyles.body),
            ),
        if (book.publisher case final publisher?)
          TafsirText(
            publisher,
            format: l10n.sourcePublisher,
            style: AppTextStyles.body,
          ),
        _Fact(
          label: l10n.sourceDigitisation,
          value: Text(page.source, style: value),
        ),
        _Fact(
          label: l10n.versionLabel,
          value: Text(arabicDigits(page.version), style: value),
        ),
        if (router != null && hasRoute(router, report))
          Button(
            label: l10n.reportError,
            variant: ButtonVariant.text,
            onPressed: () {
              Navigator.of(context).pop();
              router.push<Object?>(report);
            },
          ),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.secondary.copyWith(
            color: context.colors.inkMuted,
          ),
        ),
        value,
      ],
    ),
  );
}
