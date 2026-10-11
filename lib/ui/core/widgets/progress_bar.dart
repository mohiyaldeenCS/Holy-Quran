import 'package:flutter/widgets.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/theme/ramps.g.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';

// ProgressBar in index.jsx: `height = 6`.
const double _defaultHeight = 6;
// .qk-progress: border-radius 3px; .qk-progress-fill: border-radius inherit.
const BorderRadius _radius = BorderRadius.all(Radius.circular(3));
// .qk-progress-player: background rgba(248, 242, 228, 0.22), paper-100 at 22%.
const double _playerTrackOpacity = 0.22;

/// [primary] on the reading surfaces; [player] on the player's emerald.
enum ProgressBarTone { primary, player }

/// The identity's progress track (`ProgressBar`, `.qk-progress`). It fills
/// from the start of the line, the right in Arabic. [value] runs from 0 to 1
/// and is clamped. A screen reader reads [label] with the value as a
/// percentage.
class ProgressBar extends StatelessWidget {
  const ProgressBar({
    required this.value,
    required this.label,
    this.tone = ProgressBarTone.primary,
    this.height = _defaultHeight,
    super.key,
  });

  final double value;
  final String label;
  final ProgressBarTone tone;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fraction = value.clamp(0.0, 1.0);
    final (track, fill) = switch (tone) {
      ProgressBarTone.primary => (colors.line, colors.primary),
      ProgressBarTone.player => (
        Ramps.paper100.withValues(alpha: _playerTrackOpacity),
        colors.playerAccent,
      ),
    };
    final percent = AppLocalizations.of(
      context,
    ).percentValue(arabicDigits((fraction * 100).round()));
    // No progress-bar role: Flutter's check for it parses the value as a
    // Western number, and the value is read in Arabic-Indic digits.
    return Semantics(
      container: true,
      label: label,
      value: percent,
      child: ClipRRect(
        borderRadius: _radius,
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: DecoratedBox(
            decoration: BoxDecoration(color: track),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: FractionallySizedBox(
                widthFactor: fraction,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: fill, borderRadius: _radius),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
