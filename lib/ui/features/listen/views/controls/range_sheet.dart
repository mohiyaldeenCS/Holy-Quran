import 'package:flutter/widgets.dart' hide Icon;
import 'package:go_router/go_router.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/button.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/core/widgets/mode_chips.dart';
import 'package:holyquran/ui/core/widgets/stepper.dart';
import 'package:holyquran/ui/core/widgets/surah_name.dart';
import 'package:holyquran/ui/features/listen/view_models/controls/range_sheet_view_model.dart';
import 'package:holyquran/ui/features/listen/views/controls/controls_sheet.dart';

/// The range picker (PRD §7.7): `ModeChips` for the kind of range, shown
/// when the recitation can play more than one, and a `Stepper` for its
/// number, then play. Before any plan it is empty.
class RangeSheet extends StatelessWidget {
  const RangeSheet({required this.viewModel, super.key});

  final RangeSheetViewModel viewModel;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: viewModel,
    builder: (context, _) {
      final vm = viewModel;
      final kinds = vm.kinds;
      if (kinds.isEmpty) return const ControlsSheet(children: []);
      final l10n = AppLocalizations.of(context);
      String label(RangeKind kind) => switch (kind) {
        RangeKind.ayah => l10n.goToAyah,
        RangeKind.page => l10n.goToPage,
        RangeKind.juz => l10n.goToJuz,
        RangeKind.hizb => l10n.goToHizb,
        RangeKind.surah => l10n.goToSurah,
      };
      final surahName = vm.surahName;
      return ControlsSheet(
        chips: kinds.length > 1
            ? ModeChips(
                options: [for (final kind in kinds) label(kind)],
                selectedIndex: kinds.indexOf(vm.kind),
                onChanged: (index) => vm.selectKind(kinds[index]),
              )
            : null,
        children: [
          if (surahName != null)
            SurahName(
              surahName,
              format: SurahNameFormat.titled,
              style: AppTextStyles.bodyStrong.copyWith(
                color: context.colors.ink,
              ),
            ),
          Stepper(
            key: ValueKey(vm.kind),
            label: label(vm.kind),
            value: vm.value,
            min: vm.min,
            max: vm.max,
            onChanged: vm.setValue,
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
