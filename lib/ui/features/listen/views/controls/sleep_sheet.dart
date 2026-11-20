import 'package:flutter/semantics.dart' show SemanticsRole;
import 'package:flutter/widgets.dart';

import 'package:holyquran/domain/models/sleep_timer.dart';
import 'package:holyquran/domain/models/stop_after.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/radio_row.dart';
import 'package:holyquran/ui/core/widgets/stepper.dart';
import 'package:holyquran/ui/features/listen/view_models/controls/sleep_sheet_view_model.dart';
import 'package:holyquran/ui/features/listen/view_models/controls/stop_after_sheet_view_model.dart';
import 'package:holyquran/ui/features/listen/views/controls/controls_sheet.dart';

/// The sleep timer (`AU-07`) and, as its second section, stop after
/// (`AU-08`): a `Stepper` for the minutes, then one choice per row, each set
/// at once. Before any plan it is empty.
class SleepSheet extends StatelessWidget {
  const SleepSheet({required this.sleep, required this.stopAfter, super.key});

  final SleepSheetViewModel sleep;
  final StopAfterSheetViewModel stopAfter;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([sleep, stopAfter]),
    builder: (context, _) {
      if (!sleep.available) return const ControlsSheet(children: []);
      final l10n = AppLocalizations.of(context);
      final timer = sleep.timer;
      final minutes = sleep.minutes;
      final options = stopAfter.options;
      return ControlsSheet(
        title: l10n.playerSleepTimer,
        children: [
          Stepper(
            label: l10n.playerSleepTimer,
            value: minutes,
            min: sleep.min,
            max: sleep.max,
            onChanged: sleep.setMinutes,
          ),
          _Group(
            label: l10n.playerSleepTimer,
            rows: [
              _Choice(
                label: l10n.minutesCount(minutes, arabicDigits(minutes)),
                selected: timer == SleepAfter(minutes),
                onTap: sleep.startMinutes,
              ),
              if (sleep.offersEndOfAyah)
                _Choice(
                  label: l10n.playerEndOfAyah,
                  selected: timer is SleepAtEndOfAyah,
                  onTap: sleep.endOfAyah,
                ),
              _Choice(
                label: l10n.playerEndOfSurah,
                selected: timer is SleepAtEndOfSurah,
                onTap: sleep.endOfSurah,
              ),
              _Choice(
                label: l10n.playerSleepOff,
                selected: timer == null,
                onTap: sleep.cancel,
              ),
            ],
          ),
          if (options.isNotEmpty) ...[
            ControlsSheetTitle(l10n.stopAfterTitle),
            _Group(
              label: l10n.stopAfterTitle,
              rows: [
                for (final option in options)
                  _Choice(
                    label: stopAfterLabel(l10n, option),
                    selected: stopAfter.chosen == option,
                    onTap: () => stopAfter.choose(option),
                  ),
                _Choice(
                  label: l10n.stopAfterNone,
                  selected: stopAfter.chosen == null,
                  onTap: () => stopAfter.choose(null),
                ),
              ],
            ),
          ],
        ],
      );
    },
  );
}

/// The words of `AU-08` for [option].
String stopAfterLabel(AppLocalizations l10n, StopAfter option) =>
    switch (option) {
      StopAfter.ayah => l10n.stopAfterAyah,
      StopAfter.page => l10n.stopAfterPage,
      StopAfter.surah => l10n.stopAfterSurah,
    };

/// One set of rows of which one is chosen, read as a radio group named
/// [label]. Its rows keep the gap the sheet puts between its children.
class _Group extends StatelessWidget {
  const _Group({required this.label, required this.rows});

  final String label;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    explicitChildNodes: true,
    role: SemanticsRole.radioGroup,
    label: label,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.space4,
      children: rows,
    ),
  );
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => RadioRow(
    selected: selected,
    onTap: onTap,
    child: Text(
      label,
      style: RadioRow.labelStyle.copyWith(color: context.colors.ink),
    ),
  );
}
