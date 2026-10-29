import 'package:flutter/widgets.dart' hide Icon;
import 'package:go_router/go_router.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/ui/core/metrics/index_metrics.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/button.dart';
import 'package:holyquran/ui/core/widgets/copy_sheet.dart';
import 'package:holyquran/ui/core/widgets/mode_chips.dart';
import 'package:holyquran/ui/core/widgets/number_field.dart';
import 'package:holyquran/ui/core/widgets/place_refusal.dart';
import 'package:holyquran/ui/features/index/view_models/go_to_view_model.dart';

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
              CopySheetTitle(l10n.goToTitle),
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
                child: NumberField(
                  controller: _number,
                  label: choice.asksAyah ? l10n.goToSurah : labels[choice]!,
                  autofocus: true,
                  last: !choice.asksAyah,
                  onChanged: (_) => _viewModel.clearError(),
                  onSubmitted: choice.asksAyah ? () {} : _submit,
                ),
              ),
              if (choice.asksAyah)
                _Labelled(
                  label: l10n.goToAyah,
                  child: NumberField(
                    controller: _ayah,
                    label: l10n.goToAyah,
                    onChanged: (_) => _viewModel.clearError(),
                    onSubmitted: _submit,
                  ),
                ),
              if (error != null)
                PlaceRefusal(error: error, surahName: _viewModel.surahName),
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
