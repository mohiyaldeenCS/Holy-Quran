import 'dart:async';

import 'package:flutter/widgets.dart' hide Icon;
import 'package:go_router/go_router.dart';

import 'package:holyquran/domain/models/note.dart';
import 'package:holyquran/domain/models/pack_failure.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/routing/route_table.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/routing/routes/note_location.dart';
import 'package:holyquran/routing/routes/sheet_needs.dart';
import 'package:holyquran/ui/core/metrics/ayah_sheet_metrics.dart';
import 'package:holyquran/ui/core/metrics/sheet_rows_metrics.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/ayah_row.dart';
import 'package:holyquran/ui/core/widgets/button.dart';
import 'package:holyquran/ui/core/widgets/copy_sheet.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/core/widgets/pressable.dart';
import 'package:holyquran/ui/features/sheets/view_models/ayah_sheet_view_model.dart';
import 'package:holyquran/ui/features/sheets/views/tafsir_passage_block.dart';

/// The mini ayah sheet (`ST-01`), opened by the toolbar's study button:
/// the ayah, its tafsir, the user's notes on it and the way to play from it,
/// then «أبلغ عن خطأ» (D-127). A section with no data is not shown. The
/// study hub that replaces it is Phase 3.
///
/// The way to a screen or sheet is shown only while its route exists, as
/// every entry point does (PRD §7.1).
class AyahSheetView extends StatelessWidget {
  const AyahSheetView({required this.viewModel, super.key});

  final AyahSheetViewModel viewModel;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: viewModel,
    builder: (context, _) {
      if (viewModel.unavailable) {
        return SheetNeeds(available: (_) => false, child: const SizedBox());
      }
      final ayah = viewModel.ayahText;
      if (!viewModel.loaded || ayah == null) {
        return const CopySheetFrame(children: []);
      }
      final l10n = AppLocalizations.of(context);
      final router = GoRouter.maybeOf(context);
      final address = viewModel.address;
      bool hasPage(String location) =>
          router != null && hasRoute(router, location);
      final surahName = viewModel.surahName;
      final tafsir = viewModel.tafsir;
      final failure = tafsir.failure;
      final tafsirShown =
          tafsir.available &&
          tafsir.loaded &&
          (tafsir.page != null ||
              (failure is PackFailure && failure is! AddressNotInPack));
      return CopySheetFrame(
        children: [
          if (surahName != null)
            CopySheetTitle.surahWithAyah(surahName, ayah: address.ayah),
          AyahRow(number: address.ayah, text: ayah),
          if (tafsirShown)
            _Section(
              title: l10n.wordSheetTabTafsir,
              children: [
                TafsirPassageBlock(tafsir: tafsir),
                if (tafsir.page != null && hasPage(Routes.studyTafsir(address)))
                  Button(
                    label: l10n.tafsirReaderTitle,
                    variant: ButtonVariant.text,
                    onPressed: () => GoRouter.of(context)
                      ..pop()
                      ..go(Routes.studyTafsir(address)),
                  ),
              ],
            ),
          if (viewModel.notesAvailable && hasPage(Routes.noteSheet(address)))
            _Section(
              title: l10n.bookmarksTabNotes,
              children: [
                for (final note in viewModel.notes)
                  _NoteTile(
                    note: note,
                    onPressed: () => unawaited(
                      GoRouter.of(context).push<Object?>(
                        noteSheetLocation(address, noteId: note.id),
                      ),
                    ),
                  ),
                Button(
                  label: l10n.noteAdd,
                  variant: ButtonVariant.tonal,
                  icon: IconName.note,
                  onPressed: () => unawaited(
                    GoRouter.of(
                      context,
                    ).push<Object?>(Routes.noteSheet(address)),
                  ),
                ),
              ],
            ),
          if (viewModel.canPlay && hasPage(Routes.playOptionsSheet(address)))
            _Section(
              children: [
                Button(
                  label: l10n.contextPlayFromAyah,
                  variant: ButtonVariant.outline,
                  icon: IconName.play,
                  onPressed: () => GoRouter.of(context)
                    ..pop()
                    ..push(Routes.playOptionsSheet(address)),
                ),
              ],
            ),
          if (hasPage(Routes.reportSheet(address)))
            _Section(
              children: [
                Button(
                  label: l10n.reportError,
                  variant: ButtonVariant.text,
                  onPressed: () => GoRouter.of(context)
                    ..pop()
                    ..push(Routes.reportSheet(address)),
                ),
              ],
            ),
        ],
      );
    },
  );
}

/// A block of the sheet under its [title], set apart from the one before.
class _Section extends StatelessWidget {
  const _Section({required this.children, this.title});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    return Padding(
      padding: ayahSheetSectionPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: ayahSheetContentGap,
        children: [
          if (title != null)
            Semantics(
              header: true,
              child: Text(
                title,
                style: AppTextStyles.bodyStrong.copyWith(
                  color: context.colors.ink,
                ),
              ),
            ),
          ...children,
        ],
      ),
    );
  }
}

/// One note of the user's on the ayah, whole, as the bookmarks list shows
/// it; pressing it opens it in the note sheet.
class _NoteTile extends StatelessWidget {
  const _NoteTile({required this.note, required this.onPressed});

  final Note note;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      container: true,
      hint: AppLocalizations.of(context).noteEdit,
      child: Pressable(
        onPressed: onPressed,
        focusRadius: sheetRowsRadius,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.targetMin),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surfaceSunk,
              border: Border.all(color: colors.line),
              borderRadius: sheetRowsRadius,
            ),
            child: Padding(
              padding: ayahSheetNotePadding,
              child: Text(
                note.body,
                style: AppTextStyles.body.copyWith(color: colors.ink),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
