import 'package:flutter/widgets.dart';

import 'package:holyquran/ui/core/metrics/player_controls_metrics.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';

/// The frame of a player control sheet, after the identity's `.qk-sheet`:
/// `surface`, rounded at the top, with its handle, then the [title], a
/// `ModeChips` strip in [chips] and [children], a gap apart. Below the
/// handle it scrolls when it does not fit, as it may at 200% text.
class ControlsSheet extends StatelessWidget {
  const ControlsSheet({
    required this.children,
    this.title,
    this.chips,
    super.key,
  });

  final String? title;
  final Widget? chips;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final title = this.title;
    final chips = this.chips;
    final body = [
      if (title != null)
        Semantics(
          header: true,
          child: Text(
            title,
            style: AppTextStyles.sectionTitle.copyWith(color: colors.ink),
          ),
        ),
      ...children,
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.line)),
        borderRadius: PlayerControlsMetrics.sheetRadius,
        boxShadow: context.shadows.shadowSheet,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: PlayerControlsMetrics.sheetPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: PlayerControlsMetrics.handleSize.width,
                  height: PlayerControlsMetrics.handleSize.height,
                  decoration: BoxDecoration(
                    color: colors.lineStrong,
                    borderRadius: PlayerControlsMetrics.handleRadius,
                  ),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (chips != null) ...[
                        const SizedBox(
                          height: PlayerControlsMetrics.chipStripGap,
                        ),
                        chips,
                      ],
                      for (final (index, child) in body.indexed) ...[
                        SizedBox(
                          height: index == 0 && chips != null
                              ? PlayerControlsMetrics.chipStripGap
                              : AppSpacing.space4,
                        ),
                        child,
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
