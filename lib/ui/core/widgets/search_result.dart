import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:flutter/widgets.dart' hide Icon;

import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/icon_button.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/core/widgets/pressable.dart';
import 'package:holyquran/ui/core/widgets/quran_text.dart';
import 'package:holyquran/ui/core/widgets/surah_name.dart';

// .qk-result: border-radius 20px; padding 12px 16px 14px; gap 4px. The top
// and side paddings are space-3 and space-4, the gap space-1.
const BorderRadius _radius = BorderRadius.all(Radius.circular(20));
const double _bottomInset = 14;
// .qk-result-actions: gap 2px.
const double _actionsGap = 2;
// SearchResult in index.jsx: <IconButton … iconSize={22} />.
const double _actionIconSize = 22;
// .qk-quran-compact: font-size 22px; line-height 2.2. A clamped ayah shows
// three of its lines (D-089, 7).
const double _ayahFontSize = 22;
const double _ayahLineHeight = 2.2;
const int _clampLines = 3;
// .qk-result-fade: height 40px.
const double _fadeHeight = 40;
// .qk-result-more: min-height 32px; ::after inset -8px 0, a 48 hit area.
const double _moreHeight = 32;
const double _moreHitOutset = 8;

// No line height is set in `.qk-result*`, so each is the font's own (CSS
// `normal`); the styles do not inherit, so the ambient body line height
// cannot reach them.
// .qk-result-ref: font-size 15px; font-weight 600.
const TextStyle _referenceStyle = TextStyle(
  inherit: false,
  fontFamily: AppFonts.sans,
  fontSize: 15,
  fontWeight: FontWeight.w600,
  letterSpacing: 0,
  leadingDistribution: TextLeadingDistribution.even,
);
// .qk-result-more: font-size 14px; font-weight 600.
const TextStyle _moreStyle = TextStyle(
  inherit: false,
  fontFamily: AppFonts.sans,
  fontSize: 14,
  fontWeight: FontWeight.w600,
  letterSpacing: 0,
  leadingDistribution: TextLeadingDistribution.even,
);

/// One search result (`SearchResult`, `.qk-result`): the surah name with the
/// ayah number, the context and open-in-the-mushaf buttons, and the ayah in
/// the compact Quran size, on a `surface` card.
///
/// [ayahText] is one whole ayah from the pack, with no inline marker and no
/// match highlight (D-087, D-088). With [clamp], the ayah is cut at three
/// lines under a 40 px fade, with a link that shows it whole; the caller
/// decides which ayah is long.
class SearchResult extends StatefulWidget {
  const SearchResult({
    required this.surahName,
    required this.ayahNumber,
    required this.ayahText,
    required this.onContext,
    required this.onOpen,
    this.clamp = false,
    super.key,
  });

  final PackText surahName;
  final int ayahNumber;
  final PackText ayahText;
  final VoidCallback onContext;
  final VoidCallback onOpen;
  final bool clamp;

  @override
  State<SearchResult> createState() => _SearchResultState();
}

class _SearchResultState extends State<SearchResult> {
  bool _whole = false;

  @override
  void didUpdateWidget(SearchResult oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ayahText != widget.ayahText) _whole = false;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final cut = widget.clamp && !_whole;
    final ayah = QuranText(
      widget.ayahText,
      size: QuranTextSize.compact,
      align: QuranTextAlign.start,
    );
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.line),
        borderRadius: _radius,
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.space4,
        AppSpacing.space3,
        AppSpacing.space4,
        // The link's hit area reaches into the bottom padding.
        cut
            ? _bottomInset + AppSpacing.space1 - 2 * _moreHitOutset
            : _bottomInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // .qk-result-top: align-items center; space-between.
          Row(
            children: [
              Expanded(
                child: SurahName(
                  widget.surahName,
                  format: SurahNameFormat.withAyah,
                  ayah: widget.ayahNumber,
                  style: _referenceStyle.copyWith(color: colors.primary),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: _actionsGap,
                children: [
                  IconButton(
                    icon: IconName.context,
                    label: l10n.searchResultContext,
                    iconSize: _actionIconSize,
                    onPressed: widget.onContext,
                  ),
                  IconButton(
                    icon: IconName.mushaf,
                    label: l10n.searchResultOpen,
                    iconSize: _actionIconSize,
                    onPressed: widget.onOpen,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space1),
          if (cut) _Clamped(ayah: ayah) else ayah,
          if (cut)
            _ShowWhole(
              label: l10n.searchResultShowWhole,
              onPressed: () => setState(() => _whole = true),
            ),
        ],
      ),
    );
  }
}

/// `.qk-result-body.is-clamped` with its `.qk-result-fade`: the ayah cut at
/// three lines, fading into `surface` over its last 40 px. The cut text
/// stays whole for screen readers.
class _Clamped extends StatelessWidget {
  const _Clamped({required this.ayah});

  final Widget ayah;

  @override
  Widget build(BuildContext context) {
    final surface = context.colors.surface;
    final lines =
        MediaQuery.textScalerOf(context).scale(_ayahFontSize) *
        _ayahLineHeight *
        _clampLines;
    return Stack(
      children: [
        ClipRect(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: lines),
            child: OverflowBox(
              maxHeight: double.infinity,
              alignment: AlignmentDirectional.topStart,
              fit: OverflowBoxFit.deferToChild,
              child: ayah,
            ),
          ),
        ),
        PositionedDirectional(
          start: 0,
          end: 0,
          bottom: 0,
          height: _fadeHeight,
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: DecoratedBox(
                // linear-gradient(to bottom, transparent, var(--surface)).
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [surface.withValues(alpha: 0), surface],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// `.qk-result-more`: the link under a clamped ayah, at the row's start. Its
/// 48 hit area reaches 8 px above and below the 32 it draws, as the
/// reference's `::after` does: the box is shifted up into the gap and the
/// fade, which take no touch, and the card's bottom padding gives up the rest.
class _ShowWhole extends StatelessWidget {
  const _ShowWhole({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  static const BorderRadius _focusRadius = BorderRadius.zero;

  @override
  Widget build(BuildContext context) {
    final face = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _moreHeight),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        widthFactor: 1,
        child: Text(
          label,
          style: _moreStyle.copyWith(color: context.colors.primary),
        ),
      ),
    );
    // Transform outermost: it hit-tests its shifted child, where a box
    // would test only its own unshifted bounds.
    return Transform.translate(
      offset: const Offset(0, AppSpacing.space1 - _moreHitOutset),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Semantics(
          container: true,
          label: label,
          // Pressable covers the drawn face, where the focus ring goes; this
          // detector makes the rest of the 48 press it too.
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: _moreHitOutset),
              child: Pressable(
                onPressed: onPressed,
                focusRadius: _focusRadius,
                child: ExcludeSemantics(child: face),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
