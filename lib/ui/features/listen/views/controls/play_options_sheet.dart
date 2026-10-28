import 'package:flutter/widgets.dart' hide Icon;
import 'package:go_router/go_router.dart';

import 'package:holyquran/domain/models/playback_range.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/button.dart';
import 'package:holyquran/ui/core/widgets/surah_name.dart';
import 'package:holyquran/ui/features/listen/view_models/controls/play_options_view_model.dart';
import 'package:holyquran/ui/features/listen/views/controls/controls_sheet.dart';

/// Play from the ayah tools (`AU-03`): the ayah, then one button for each
/// end the recitation can play.
class PlayOptionsSheet extends StatelessWidget {
  const PlayOptionsSheet({required this.viewModel, super.key});

  final PlayOptionsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final vm = viewModel;
    final options = vm.options;
    final surahName = vm.surahName;
    return ControlsSheet(
      children: [
        if (options.isNotEmpty && surahName != null)
          SurahName(
            surahName,
            format: SurahNameFormat.withAyah,
            ayah: vm.address.ayah,
            style: AppTextStyles.bodyStrong.copyWith(color: context.colors.ink),
          ),
        for (final until in options)
          Button(
            label: playToLabel(l10n, until),
            variant: ButtonVariant.outline,
            onPressed: () async {
              if (await vm.play(until) && context.mounted) context.pop();
            },
          ),
      ],
    );
  }
}

/// The words of `AU-03` for [until].
String playToLabel(AppLocalizations l10n, AyahToolEnd until) => switch (until) {
  AyahToolEnd.ayah => l10n.playOnlyAyah,
  AyahToolEnd.page => l10n.playToPageEnd,
  AyahToolEnd.surah => l10n.playToSurahEnd,
  AyahToolEnd.juz => l10n.playToJuzEnd,
  AyahToolEnd.untilStopped => l10n.playUntilStopped,
};
