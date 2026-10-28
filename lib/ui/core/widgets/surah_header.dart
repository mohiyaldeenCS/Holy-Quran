import 'package:flutter/widgets.dart';

import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/pressable.dart';
import 'package:holyquran/ui/core/widgets/star_outline.dart';
import 'package:holyquran/ui/core/widgets/surah_name.dart';

/// The two sizes of the surah header: [md] on the page, [lg] where the surah
/// begins.
enum SurahHeaderSize { md, lg }

/// The surah header: a double frame with a quarter star on each side of the
/// name, and an optional [info] line under the inner frame. [name] is the
/// pack's surah name without the word for surah, which the header adds
/// (`surahTitle`, drawn by [SurahName]).
///
/// The reference heights are minimum heights, so the name can grow with the
/// system text scale.
///
/// With [onInfoPressed], the whole header is one button that opens «مقدمة
/// السورة» (`RD-17`); it needs an [info] line to open it from. The header is
/// taller than the 48 hit area at every size, so the tap target adds nothing
/// to what is drawn.
final class SurahHeader extends StatelessWidget {
  const SurahHeader({
    required this.name,
    this.size = SurahHeaderSize.md,
    this.info,
    this.onInfoPressed,
    super.key,
  }) : assert(onInfoPressed == null || info != null);

  final PackText name;
  final SurahHeaderSize size;
  final String? info;
  final VoidCallback? onInfoPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final large = size == SurahHeaderSize.lg;
    final star = StarOutline(size: large ? _largeStarSize : _starSize);
    final info = this.info;
    final onInfoPressed = this.onInfoPressed;
    final header = Container(
      padding: const EdgeInsets.all(AppSpacing.space1),
      decoration: BoxDecoration(
        border: Border.all(color: colors.ornament, width: _outerBorderWidth),
        borderRadius: _outerBorderRadius,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // CSS content-box: the height is inside the border.
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: colors.ornamentSoft),
              borderRadius: BorderRadius.circular(_innerRadius),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: large ? _largeInnerHeight : _innerHeight,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: AppSpacing.space4,
                children: [
                  star,
                  Flexible(
                    child: SurahName(
                      name,
                      format: SurahNameFormat.titled,
                      textAlign: TextAlign.center,
                      style: (large ? _largeNameStyle : _nameStyle).copyWith(
                        color: colors.primary,
                      ),
                    ),
                  ),
                  star,
                ],
              ),
            ),
          ),
          if (info != null)
            Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.space2,
                bottom: _infoBottomPadding,
              ),
              child: Text(
                info,
                textAlign: TextAlign.center,
                style: _infoStyle.copyWith(color: colors.inkMuted),
              ),
            ),
        ],
      ),
    );
    if (onInfoPressed == null) return header;
    return Semantics(
      container: true,
      hint: AppLocalizations.of(context).surahIntroTitle,
      child: Pressable(
        onPressed: onInfoPressed,
        focusRadius: _outerBorderRadius,
        child: header,
      ),
    );
  }
}

// .qk-surah-header: `border: 1.5px solid var(--ornament); border-radius:
// 14px; padding: 4px`; the padding is space-1.
const double _outerBorderWidth = 1.5;
const double _outerRadius = 14;
final BorderRadius _outerBorderRadius = BorderRadius.circular(_outerRadius);

// .qk-surah-header-inner: `border: 1px solid var(--ornament-soft);
// border-radius: 10px; height: 56px`; .qk-surah-header-lg: `height: 64px`.
// The 1px border is Border.all's default width; the gap of 16px is space-4.
const double _innerRadius = 10;
const double _innerHeight = 56;
const double _largeInnerHeight = 64;

// SurahHeader in index.jsx: `<StarOutline size={size === 'lg' ? 32 : 28} />`.
const double _starSize = 28;
const double _largeStarSize = 32;

// .qk-surah-header-name: Reem Kufi, `font-size: 26px; font-weight: 600`;
// .qk-surah-header-lg: `font-size: 30px`. No line height is set, so it is the
// font's own (CSS `normal`), as a TextStyle with no height draws it; the
// styles do not inherit, so the ambient body line height cannot reach them.
const TextStyle _nameStyle = TextStyle(
  inherit: false,
  fontFamily: AppFonts.kufi,
  fontFamilyFallback: [AppFonts.sans],
  fontSize: 26,
  fontWeight: FontWeight.w600,
  letterSpacing: 0,
  leadingDistribution: TextLeadingDistribution.even,
);
const TextStyle _largeNameStyle = TextStyle(
  inherit: false,
  fontFamily: AppFonts.kufi,
  fontFamilyFallback: [AppFonts.sans],
  fontSize: 30,
  fontWeight: FontWeight.w600,
  letterSpacing: 0,
  leadingDistribution: TextLeadingDistribution.even,
);

// .qk-surah-header-info: `padding: var(--space-2) 0 2px; font-size: 14px;
// color: var(--ink-muted)`, in the body's IBM Plex Sans Arabic 400 with its
// `normal` line height.
const double _infoBottomPadding = 2;
const TextStyle _infoStyle = TextStyle(
  inherit: false,
  fontFamily: AppFonts.sans,
  fontSize: 14,
  fontWeight: FontWeight.w400,
  letterSpacing: 0,
  leadingDistribution: TextLeadingDistribution.even,
);
