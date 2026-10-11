import 'package:flutter/widgets.dart' hide Icon;

import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/icon.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/core/widgets/pressable.dart';

/// One door of the home screen into a section (Screens.dc.html, the home
/// board's four-column grid): an icon on a rounded tile over its [label].
/// The whole door is the button.
final class HomeDoor extends StatelessWidget {
  const HomeDoor({
    required this.icon,
    required this.label,
    required this.onPressed,
    super.key,
  });

  final IconName icon;
  final String label;
  final VoidCallback onPressed;

  static final BorderRadius _radius = BorderRadius.circular(_tileRadius);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      container: true,
      label: label,
      child: Pressable(
        onPressed: onPressed,
        focusRadius: _radius,
        child: ExcludeSemantics(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: _labelGap,
            children: [
              Container(
                width: _tileSize,
                height: _tileSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.surfaceSunk,
                  borderRadius: _radius,
                ),
                child: Icon(icon, size: _iconSize, color: colors.primary),
              ),
              Text(
                label,
                textAlign: TextAlign.center,
                style: _labelStyle.copyWith(color: colors.ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Screens.dc.html, home doors: the tile is `width:56px;height:56px;
// border-radius:18px` on #EFE6D0 (surface-sunk), its icon `<svg width="26"
// height="26">` in #0E5A52 (primary).
const double _tileSize = 56;
const double _tileRadius = 18;
const double _iconSize = 26;

// Screens.dc.html, home doors: the door is a column with `gap:6px`.
const double _labelGap = 6;

// Screens.dc.html, home doors: the label is `font-size:13px;font-weight:500`
// in the body's IBM Plex Sans Arabic and colour (#1B2A28, ink). No line height
// is set, so it is the font's own (CSS `normal`), as a TextStyle with no
// height draws it.
const TextStyle _labelStyle = TextStyle(
  inherit: false,
  fontFamily: AppFonts.sans,
  fontSize: 13,
  fontWeight: FontWeight.w500,
  letterSpacing: 0,
  leadingDistribution: TextLeadingDistribution.even,
);
