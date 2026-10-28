import 'package:flutter/widgets.dart' hide Icon;
import 'package:go_router/go_router.dart';

import 'package:holyquran/domain/models/edition_map.dart';
import 'package:holyquran/domain/models/go_to_error.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/metrics/index_metrics.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/button.dart';
import 'package:holyquran/ui/core/widgets/copy_sheet.dart';
import 'package:holyquran/ui/core/widgets/icon.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/core/widgets/mode_chips.dart';
import 'package:holyquran/ui/core/widgets/surah_name.dart';
import 'package:holyquran/ui/features/index/view_models/go_to_view_model.dart';
import 'package:holyquran/ui/features/index/views/go_to_field.dart';

/// The go-to sheet (`NV-03`): the six targets, one or two numbers in either
/// digit system, and «اذهب إلى». A valid input closes the sheet and opens the
/// reader at the first ayah of the place; an invalid one stays, with the
/// sentence that names the reason. The identity does not draw this sheet: it
/// takes the frame of the copy sheet and the search field's box for its
/// numbers.
class GoToSheet extends StatefulWidget {
  const GoToSheet({required this.viewModel, super.key});

  final GoToViewModel viewModel;

  @override
  State<GoToSheet> createState() => _GoToSheetState();
}

class _GoToSheetState extends State<GoToSheet> {
  final _number = TextEditingController();
  final _ayah = TextEditingController();

  GoToViewModel get _viewModel => widget.viewModel;

  @override
  void dispose() {
    _number.dispose();
    _ayah.dispose();
    super.dispose();
  }

  void _submit() {
    final target = _viewModel.submit(_number.text, ayah: _ayah.text);
    if (target == null) return;
    // The sheet closes and the reader is pushed over what lay under it, so
    // that Back returns there.
    final router = GoRouter.of(context);
    router
      ..pop()
      ..push(Routes.mushafRead(target.start));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final labels = {
      GoToChoice.surah: l10n.goToSurah,
      GoToChoice.ayah: l10n.goToAyah,
      GoToChoice.page: l10n.goToPage,
      GoToChoice.juz: l10n.goToJuz,
      GoToChoice.hizb: l10n.goToHizb,
      GoToChoice.rub: l10n.goToRub,
    };
    return Padding(
      padding: IndexMetrics.keyboardInset(context),
      child: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          final choice = _viewModel.choice;
          final error = _viewModel.error;
          return CopySheetFrame(
            children: [
              Semantics(
                header: true,
                child: Text(
                  l10n.goToTitle,
                  style: AppTextStyles.sectionTitle.copyWith(color: colors.ink),
                ),
              ),
              ModeChips(
                label: l10n.goToTitle,
                options: [
                  for (final choice in GoToChoice.values) labels[choice]!,
                ],
                selectedIndex: choice.index,
                onChanged: (index) =>
                    _viewModel.select(GoToChoice.values[index]),
              ),
              _Labelled(
                label: choice.asksAyah ? l10n.goToSurah : null,
                child: GoToField(
                  controller: _number,
                  label: choice.asksAyah ? l10n.goToSurah : labels[choice]!,
                  autofocus: true,
                  last: !choice.asksAyah,
                  onChanged: _viewModel.clearError,
                  onSubmitted: choice.asksAyah ? () {} : _submit,
                ),
              ),
              if (choice.asksAyah)
                _Labelled(
                  label: l10n.goToAyah,
                  child: GoToField(
                    controller: _ayah,
                    label: l10n.goToAyah,
                    onChanged: _viewModel.clearError,
                    onSubmitted: _submit,
                  ),
                ),
              if (error != null) _Refusal(error, _viewModel),
              CopySheetFrame.action(
                Button(label: l10n.goToTitle, onPressed: _submit),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A field with its name above it, shown when the sheet has two fields.
class _Labelled extends StatelessWidget {
  const _Labelled({required this.child, this.label});

  final String? label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final label = this.label;
    if (label == null) return child;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.space1,
      children: [
        ExcludeSemantics(
          child: Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: context.colors.inkMuted,
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// The sentence that names why the input was refused, with the alert icon so
/// that the state is not told by colour alone.
class _Refusal extends StatelessWidget {
  const _Refusal(this.error, this.viewModel);

  final GoToError error;
  final GoToViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final style = AppTextStyles.secondary.copyWith(color: colors.error);
    final sentence = switch (error) {
      NoSuchAyah(:final surah, :final ayah) => _ayahMissing(
        l10n,
        viewModel.surahName(surah),
        ayah,
        style,
      ),
      NoSuchSurah(:final surah) => Text(
        l10n.surahNumberNotFound(arabicDigits(surah)),
        style: style,
      ),
      DivisionOutOfRange(:final division, :final number) => Text(
        _divisionMissing(l10n, division, arabicDigits(number)),
        style: style,
      ),
      UnreadableGoTo() => Text(l10n.addressUnreadable, style: style),
    };
    return Semantics(
      liveRegion: true,
      container: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.space2,
        children: [
          Icon(IconName.alert, color: colors.error),
          Expanded(child: sentence),
        ],
      ),
    );
  }
}

String _divisionMissing(
  AppLocalizations l10n,
  Division division,
  String number,
) => switch (division) {
  Division.page => l10n.pageNotFound(number),
  Division.juz => l10n.juzNotFound(number),
  Division.hizb => l10n.hizbNotFound(number),
  Division.rub => l10n.rubNotFound(number),
};

// The sentence «لا توجد آية {ayah} في {surah}» with the surah's name from the
// pack set by SurahName, the only widget that draws a name (D-084), at the
// place the sentence has for it.
const String _nameSlot = '\u0000';

Widget _ayahMissing(
  AppLocalizations l10n,
  PackText? name,
  int ayah,
  TextStyle style,
) {
  if (name == null) return Text(l10n.addressUnreadable, style: style);
  final parts = l10n
      .ayahNotInSurah(arabicDigits(ayah), _nameSlot)
      .split(_nameSlot);
  return Text.rich(
    TextSpan(
      style: style,
      children: [
        TextSpan(text: parts.first),
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: SurahName(name, style: style),
        ),
        TextSpan(text: parts.last),
      ],
    ),
  );
}
