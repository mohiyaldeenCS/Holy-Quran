import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/metrics/player_metrics.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/focus_ring.dart';
import 'package:holyquran/ui/core/widgets/progress_bar.dart';

// Not drawn: the track has no keyboard state in the board, so its focus ring
// sits square round the target-min band, as the other bare targets' do.
const BorderRadius _focusRadius = BorderRadius.zero;

/// The player-tone [ProgressBar] in a target-min band that seeks where it
/// is tapped or dragged, from the right in Arabic; a screen reader moves it
/// by [PlayerMetrics.seekStep], and so do the arrow keys while it has focus,
/// the one toward the start of the line going back (`AX-09`, D-169).
class SeekTrack extends StatefulWidget {
  const SeekTrack({
    required this.progress,
    this.onSeek,
    this.onSeekBy,
    super.key,
  });

  final double progress;
  final ValueChanged<double>? onSeek;
  final ValueChanged<Duration>? onSeekBy;

  @override
  State<SeekTrack> createState() => _SeekTrackState();
}

final class _SeekIntent extends Intent {
  const _SeekIntent({required this.forward});

  final bool forward;
}

class _SeekTrackState extends State<SeekTrack> {
  /// Where a drag holds the track; it seeks once, on release.
  double? _dragged;

  double? _fractionAt(double dx) {
    final width = context.size?.width ?? 0;
    if (width <= 0) return null;
    final fraction = (dx / width).clamp(0.0, 1.0);
    return Directionality.of(context) == TextDirection.rtl
        ? 1 - fraction
        : fraction;
  }

  void _drag(DragUpdateDetails details) =>
      setState(() => _dragged = _fractionAt(details.localPosition.dx));

  void _release(ValueChanged<double> onSeek) {
    final dragged = _dragged;
    setState(() => _dragged = null);
    if (dragged != null) onSeek(dragged);
  }

  @override
  Widget build(BuildContext context) {
    final onSeek = widget.onSeek;
    final onSeekBy = widget.onSeekBy;
    // The line runs from the right in Arabic, so the arrow toward its end is
    // the left one there.
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return MergeSemantics(
      child: Semantics(
        onIncrease: onSeekBy == null
            ? null
            : () => onSeekBy(PlayerMetrics.seekStep),
        onDecrease: onSeekBy == null
            ? null
            : () => onSeekBy(-PlayerMetrics.seekStep),
        child: FocusRing(
          radius: _focusRadius,
          child: FocusableActionDetector(
            enabled: onSeekBy != null,
            shortcuts: {
              const SingleActivator(LogicalKeyboardKey.arrowLeft): _SeekIntent(
                forward: rtl,
              ),
              const SingleActivator(LogicalKeyboardKey.arrowRight): _SeekIntent(
                forward: !rtl,
              ),
            },
            actions: {
              _SeekIntent: CallbackAction<_SeekIntent>(
                onInvoke: (intent) {
                  onSeekBy?.call(
                    intent.forward
                        ? PlayerMetrics.seekStep
                        : -PlayerMetrics.seekStep,
                  );
                  return null;
                },
              ),
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              excludeFromSemantics: true,
              onTapUp: onSeek == null
                  ? null
                  : (details) {
                      if (_fractionAt(details.localPosition.dx)
                          case final at?) {
                        onSeek(at);
                      }
                    },
              onHorizontalDragUpdate: onSeek == null ? null : _drag,
              onHorizontalDragEnd: onSeek == null
                  ? null
                  : (_) => _release(onSeek),
              onHorizontalDragCancel: () => setState(() => _dragged = null),
              child: SizedBox(
                height: AppSizes.targetMin,
                child: Center(
                  child: ProgressBar(
                    value: _dragged ?? widget.progress,
                    tone: ProgressBarTone.player,
                    label: AppLocalizations.of(context).playerPosition,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
