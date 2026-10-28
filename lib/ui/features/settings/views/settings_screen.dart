import 'package:flutter/material.dart' hide IconButton, Switch;
import 'package:go_router/go_router.dart';

import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/domain/models/ui_level.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/metrics/settings_metrics.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/icon_button.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/core/widgets/level_switch.dart';
import 'package:holyquran/ui/core/widgets/switch.dart';
import 'package:holyquran/ui/features/settings/view_models/settings_view_model.dart';
import 'package:provider/provider.dart';

/// The settings (PRD §7.1), an extension that follows the pushed player
/// screen of the Screens2 board. Text size, opening at the last position and
/// keeping the screen awake wait for their labels (PHASE1.md, Appendix B).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final viewModel = context.watch<SettingsViewModel>();
    final preference = viewModel.themePreference;
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: SettingsMetrics.header,
            child: Row(
              children: [
                IconButton(
                  icon: IconName.previous,
                  label: l10n.back,
                  tone: IconButtonTone.tint,
                  onPressed: () => context.pop(),
                ),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      l10n.settingsTitle,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyStrong.copyWith(
                        color: context.colors.ink,
                      ),
                    ),
                  ),
                ),
                // Balances the back button, so the title sits in the middle
                // as on the board.
                const SizedBox(width: AppSizes.targetMin),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: SettingsMetrics.content,
              children: [
                _SectionTitle(l10n.levelLabel),
                const SizedBox(height: SettingsMetrics.contentGap),
                LevelSwitch(
                  options: [
                    for (final level in UiLevel.values) l10n.level(level),
                  ],
                  selectedIndex: viewModel.level.index,
                  onChanged: (index) =>
                      viewModel.selectLevel(UiLevel.values[index]),
                  semanticLabel: l10n.levelLabel,
                ),
                const SizedBox(height: AppSpacing.space5),
                _SectionTitle(l10n.themeLabel),
                const SizedBox(height: SettingsMetrics.contentGap),
                LevelSwitch(
                  options: [
                    for (final theme in ReadingTheme.values) l10n.theme(theme),
                  ],
                  selectedIndex: preference.theme.index,
                  onChanged: (index) =>
                      viewModel.selectTheme(ReadingTheme.values[index]),
                  semanticLabel: l10n.themeLabel,
                ),
                const SizedBox(height: SettingsMetrics.contentGap),
                Switch(
                  label: l10n.followSystemDark,
                  value: viewModel.followSystemDark,
                  onChanged: (_) => viewModel.toggleFollowSystemDark(),
                ),
                const SizedBox(height: AppSpacing.space5),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(
      text,
      style: AppTextStyles.sectionTitle.copyWith(color: context.colors.ink),
    ),
  );
}

extension on AppLocalizations {
  String level(UiLevel level) => switch (level) {
    UiLevel.simple => levelSimple,
    UiLevel.medium => levelMedium,
    UiLevel.study => levelStudy,
  };

  String theme(ReadingTheme theme) => switch (theme) {
    ReadingTheme.paper => themePaper,
    ReadingTheme.night => themeNight,
    ReadingTheme.sepia => themeSepia,
    ReadingTheme.contrast => themeContrast,
  };
}
