import 'package:flutter/material.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/level_switch.dart';

import 's7_record.dart';
import 's7_session.dart';
import 'tap_resolver.dart';
import 'target_practice.dart';

/// The S7 debug chrome, in the spike's English (D-072): the mode, the
/// interface level (the identity's `LevelSwitch`), the tap rule, practice,
/// the counts and the log export. Numbers, enum names and paths only.
final class S7DebugPanel extends StatelessWidget {
  const S7DebugPanel({
    required this.mode,
    required this.onMode,
    required this.surahAvailable,
    required this.level,
    required this.onLevel,
    required this.rule,
    required this.defaultRule,
    required this.onRule,
    required this.step,
    required this.systemScale,
    required this.practising,
    required this.onPractice,
    required this.record,
    required this.onExport,
    this.exportStatus,
    super.key,
  });

  final S7Mode mode;
  final ValueChanged<S7Mode> onMode;
  final bool surahAvailable;
  final S7Level level;
  final ValueChanged<S7Level> onLevel;
  final TapRule rule;
  final TapRule defaultRule;
  final ValueChanged<TapRule> onRule;
  final double step;
  final double systemScale;
  final bool practising;
  final ValueChanged<bool> onPractice;
  final S7Record record;
  final VoidCallback onExport;
  final String? exportStatus;

  @override
  Widget build(BuildContext context) {
    final log = record.log;
    final heading = Theme.of(context).textTheme.titleMedium;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.space4),
        children: [
          Text('S7 gestures', style: Theme.of(context).textTheme.titleLarge),
          Text('Mode', style: heading),
          SegmentedButton<S7Mode>(
            segments: [
              ButtonSegment(
                value: S7Mode.surah,
                label: const Text('Surah'),
                enabled: surahAvailable,
              ),
              const ButtonSegment(value: S7Mode.page, label: Text('Page')),
            ],
            selected: {mode},
            onSelectionChanged: (selected) => onMode(selected.single),
          ),
          Text('Level', style: heading),
          s7Arabic(
            context,
            Builder(
              builder: (context) {
                final l10n = AppLocalizations.of(context);
                return LevelSwitch(
                  options: [
                    l10n.levelSimple,
                    l10n.levelMedium,
                    l10n.levelStudy,
                  ],
                  selectedIndex: level.index,
                  onChanged: (index) => onLevel(S7Level.values[index]),
                  semanticLabel: l10n.levelLabel,
                );
              },
            ),
          ),
          Text('Tap rule', style: heading),
          Wrap(
            spacing: AppSpacing.space2,
            children: [
              for (final value in TapRule.values)
                ChoiceChip(
                  label: Text(
                    value == defaultRule
                        ? '${value.name} (default)'
                        : value.name,
                  ),
                  selected: value == rule,
                  onSelected: (_) => onRule(value),
                ),
            ],
          ),
          Text(
            'Text size ${step}x (system ${systemScale.toStringAsFixed(2)}x)',
          ),
          Text('Practice', style: heading),
          Wrap(
            spacing: AppSpacing.space2,
            children: [
              FilledButton(
                onPressed: mode == S7Mode.surah
                    ? () => onPractice(!practising)
                    : null,
                child: Text(practising ? 'Stop practice' : 'Start practice'),
              ),
            ],
          ),
          for (final MapEntry(:key, :value) in hitRatesByKind(
            log.entries,
          ).entries)
            Text('${key.name}: ${value.hits} of ${value.trials} hit'),
          for (final MapEntry(:key, :value) in hitRatesByRule(
            log.entries,
          ).entries)
            Text('$key: ${value.hits} of ${value.trials} hit'),
          Text('Log', style: heading),
          Text('${log.entries.length} entries, ${log.dropped} dropped'),
          for (final MapEntry(:key, :value) in record.toolbarActions.entries)
            Text('Toolbar ${key.name}: $value'),
          Wrap(
            children: [
              FilledButton(
                onPressed: onExport,
                child: const Text('Export log'),
              ),
            ],
          ),
          if (exportStatus case final status?) Text(status),
        ],
      ),
    );
  }
}
