import 'package:flutter/material.dart' hide Icon, IconButton;

import 'package:holyquran/domain/models/playback_plan.dart';
import 'package:holyquran/domain/models/playback_range.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/metrics/player_controls_metrics.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/icon_button.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/core/widgets/surah_name.dart';
import 'package:holyquran/ui/features/listen/view_models/controls/queue_sheet_view_model.dart';
import 'package:holyquran/ui/features/listen/views/controls/controls_sheet.dart';
import 'package:holyquran/ui/features/listen/views/controls/play_options_sheet.dart';

/// The queue (`AU-17`) under its name «قائمة التشغيل» (D-127): one row per
/// waiting plan, moved by a long press and drag or by the screen reader's
/// move actions, and removed with its button.
class QueueSheet extends StatelessWidget {
  const QueueSheet({required this.viewModel, super.key});

  final QueueSheetViewModel viewModel;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: viewModel,
    builder: (context, _) {
      final queue = viewModel.queue;
      final seen = <PlaybackPlan, int>{};
      return ControlsSheet(
        title: AppLocalizations.of(context).queueLabel,
        children: [
          if (queue.isNotEmpty)
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              proxyDecorator: (child, index, animation) =>
                  ColoredBox(color: context.colors.surface, child: child),
              onReorderItem: viewModel.move,
              children: [
                for (final (index, plan) in queue.indexed)
                  ReorderableDelayedDragStartListener(
                    // The same plan may wait twice; each stays its own row.
                    key: ValueKey((
                      plan,
                      seen.update(plan, (n) => n + 1, ifAbsent: () => 0),
                    )),
                    index: index,
                    child: _QueueRow(
                      plan: plan,
                      last: index == queue.length - 1,
                      viewModel: viewModel,
                      onRemove: () => viewModel.remove(index),
                    ),
                  ),
              ],
            ),
        ],
      );
    },
  );
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({
    required this.plan,
    required this.last,
    required this.viewModel,
    required this.onRemove,
  });

  final PlaybackPlan plan;

  /// `.qk-sheet-row:last-child` draws no line under it.
  final bool last;
  final QueueSheetViewModel viewModel;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final placeStyle = AppTextStyles.bodyStrong.copyWith(color: colors.ink);
    final range = plan.range;
    final until = range is FromAyahTool ? range.until : null;
    // .qk-sheet-row: gap var(--space-4).
    final row = Row(
      spacing: AppSpacing.space4,
      children: [
        Expanded(
          child: MergeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ?_place(l10n, range, placeStyle),
                if (until != null)
                  Text(
                    playToLabel(l10n, until),
                    style: AppTextStyles.secondary.copyWith(
                      color: colors.inkMuted,
                    ),
                  ),
                Text(
                  plan.recitation.reciter,
                  style: AppTextStyles.secondary.copyWith(
                    color: colors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
        IconButton(
          icon: IconName.close,
          label: l10n.resourceDelete,
          onPressed: onRemove,
        ),
      ],
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: colors.line)),
      ),
      child: Padding(
        padding: PlayerControlsMetrics.sheetRowPadding,
        child: row,
      ),
    );
  }

  /// Where [range] is, for the ranges one line names exactly.
  Widget? _place(AppLocalizations l10n, PlaybackRange range, TextStyle style) {
    Widget? named(int surah, {int? ayah}) =>
        switch (viewModel.surahName(surah)) {
          final name? => SurahName(
            name,
            format: ayah == null
                ? SurahNameFormat.titled
                : SurahNameFormat.withAyah,
            ayah: ayah,
            style: style,
          ),
          null => null,
        };
    return switch (range) {
      WholeSurah(:final surah) => named(surah),
      SingleAyah(:final ayah) ||
      FromAyahTool(:final ayah) => named(ayah.surah, ayah: ayah.ayah),
      PageSpan(:final first, :final last) when first == last => Text(
        l10n.pageLabel(arabicDigits(first)),
        style: style,
      ),
      WholeJuz(:final juz) => Text(
        l10n.juzLabel(arabicDigits(juz)),
        style: style,
      ),
      WholeHizb(:final hizb) => Text(
        l10n.hizbLabel(arabicDigits(hizb)),
        style: style,
      ),
      PageSpan() || AyahSpan() || SurahSet() || ToEndOfMushaf() => null,
    };
  }
}
