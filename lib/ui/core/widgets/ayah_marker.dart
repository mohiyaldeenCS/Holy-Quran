import 'package:flutter/widgets.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/theme/ramps.g.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';

/// The ayah-end marker: a thin `ornament` ring with the ayah number inside in
/// `accent`. While its ayah is recited ([playing]) the ring fills, so the
/// state shows as a shape and not only as a colour.
///
/// The diameter follows the system text scale; the digits are sized from the
/// scaled diameter and are not scaled again.
final class AyahMarker extends StatelessWidget {
  const AyahMarker({
    required this.number,
    this.playing = false,
    this.size = AppSizes.ayahMarker,
    this.ringWidth = _ringWidth,
    super.key,
  });

  final int number;
  final bool playing;
  final double size;

  /// The ring's stroke; `AyahRow` draws it thicker (`.qk-ayah-row .qk-ayah-no`).
  final double ringWidth;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final digits = arabicDigits(number);
    final diameter = MediaQuery.textScalerOf(context).scale(size);
    final digitScale = digits.length > _longNumberDigits
        ? _longNumberScale
        : _numberScale;
    return Semantics(
      container: true,
      label: AppLocalizations.of(context).ayahMarkerLabel(digits),
      child: ExcludeSemantics(
        child: Container(
          width: diameter,
          height: diameter,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: playing ? colors.ornament : null,
            border: Border.all(color: colors.ornament, width: ringWidth),
          ),
          child: Text(
            digits,
            maxLines: 1,
            softWrap: false,
            textScaler: TextScaler.noScaling,
            style: AppTextStyles.caption.copyWith(
              fontSize: diameter * digitScale,
              height: _numberHeight,
              color: playing ? Ramps.emerald950 : colors.accent,
            ),
          ),
        ),
      ),
    );
  }
}

// AyahMarker in index.jsx: `fontSize: n.length > 2 ? size * 0.38 :
// size * 0.46`. The family and weight (IBM Plex Sans Arabic 600) are those of
// the caption style.
const int _longNumberDigits = 2;
const double _longNumberScale = 0.38;
const double _numberScale = 0.46;

// .qk-ayah-no: `border: 1.2px solid var(--ornament)`.
const double _ringWidth = 1.2;

// .qk-ayah-no: `line-height: 1`.
const double _numberHeight = 1;
