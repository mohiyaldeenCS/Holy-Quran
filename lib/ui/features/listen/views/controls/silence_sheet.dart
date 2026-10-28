import 'package:flutter/widgets.dart' hide Icon;
import 'package:go_router/go_router.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/widgets/button.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/core/widgets/stepper.dart';
import 'package:holyquran/ui/features/listen/view_models/controls/silence_sheet_view_model.dart';
import 'package:holyquran/ui/features/listen/views/controls/controls_sheet.dart';

/// The silence between ayat (`AU-11`): a `Stepper` from 0 to 30 seconds,
/// then play. Before any plan it is empty.
class SilenceSheet extends StatelessWidget {
  const SilenceSheet({required this.viewModel, super.key});

  final SilenceSheetViewModel viewModel;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: viewModel,
    builder: (context, _) {
      final vm = viewModel;
      if (!vm.available) return const ControlsSheet(children: []);
      final l10n = AppLocalizations.of(context);
      return ControlsSheet(
        children: [
          Stepper(
            label: l10n.playerSilenceBetweenAyat,
            value: vm.seconds,
            unit: l10n.playerSecondsUnit,
            min: vm.min,
            max: vm.max,
            onChanged: vm.setSeconds,
          ),
          Button(
            label: l10n.playerPlay,
            icon: IconName.play,
            onPressed: () async {
              if (await vm.play() && context.mounted) context.pop();
            },
          ),
        ],
      );
    },
  );
}
