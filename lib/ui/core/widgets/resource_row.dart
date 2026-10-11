import 'package:flutter/widgets.dart' hide Icon;

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/icon.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/core/widgets/pressable.dart';
import 'package:holyquran/ui/core/widgets/progress_bar.dart';

// .qk-resource: padding 14px 0.
const double _paddingVertical = 14;
// .qk-resource-main: gap 6px.
const double _mainGap = 6;
// ResourceRow in index.jsx: `<Icon name="check" size={16} />`.
const double _checkSize = 16;
// .qk-btn-small: height 44px; border-radius 14px.
const double _buttonHeight = 44;
const double _buttonRadius = 14;
// .qk-btn-small-outline: box-shadow inset 0 0 0 1.5px var(--line).
const double _outlineWidth = 1.5;

// .qk-resource-title: font-size 17px; font-weight 600. .qk-resource-meta:
// font-size 14px; .is-done: font-weight 500. .qk-resource-pct and
// .qk-btn-small: font-size 15px; font-weight 600. The body's IBM Plex Sans
// Arabic with its `normal` line height.
const TextStyle _titleStyle = TextStyle(
  inherit: false,
  fontFamily: AppFonts.sans,
  fontSize: 17,
  fontWeight: FontWeight.w600,
  letterSpacing: 0,
  leadingDistribution: TextLeadingDistribution.even,
);
final TextStyle _metaStyle = _titleStyle.copyWith(
  fontSize: 14,
  fontWeight: FontWeight.w400,
);
final TextStyle _doneMetaStyle = _metaStyle.copyWith(
  fontWeight: FontWeight.w500,
);
final TextStyle _smallStyle = _titleStyle.copyWith(fontSize: 15);

/// The three states of a resource the reference draws (D-088).
enum ResourceStatus { available, downloading, downloaded }

/// A row of the resource manager (`ResourceRow`, `.qk-resource`): the title
/// over its status, and at the end the action. The status is always in
/// words: «متاحة» with a download button, a track with the percentage while
/// it downloads, «تم التنزيل» with a check mark and a delete button.
///
/// A null [size] leaves the status word alone. [progress] runs from 0 to 1.
/// [onAction] downloads or deletes; it is unused while downloading. [divider]
/// draws the bottom hairline, which the reference drops on the last row.
class ResourceRow extends StatelessWidget {
  const ResourceRow({
    required this.title,
    required this.status,
    this.size,
    this.progress = 0,
    this.onAction,
    this.divider = true,
    super.key,
  }) : assert(status == ResourceStatus.downloading || onAction != null);

  final String title;
  final ResourceStatus status;
  final String? size;
  final double progress;
  final VoidCallback? onAction;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final size = this.size;
    final fraction = progress.clamp(0.0, 1.0);
    final Widget status = switch (this.status) {
      ResourceStatus.downloading => ProgressBar(
        value: fraction,
        label: l10n.resourceDownloading(title),
      ),
      ResourceStatus.downloaded => Row(
        spacing: AppSpacing.space1,
        children: [
          Icon(IconName.check, size: _checkSize, color: colors.success),
          Flexible(
            child: Text(
              size == null
                  ? l10n.resourceDownloaded
                  : l10n.resourceDownloadedMeta(size),
              style: _doneMetaStyle.copyWith(color: colors.success),
            ),
          ),
        ],
      ),
      ResourceStatus.available => Text(
        size == null
            ? l10n.resourceAvailable
            : l10n.resourceAvailableMeta(size),
        style: _metaStyle.copyWith(color: colors.inkMuted),
      ),
    };
    final Widget end = switch (this.status) {
      // The track already reads this percentage as its value.
      ResourceStatus.downloading => ExcludeSemantics(
        child: Text(
          l10n.percentValue(arabicDigits((fraction * 100).round())),
          style: _smallStyle.copyWith(color: colors.primary),
        ),
      ),
      ResourceStatus.downloaded => _SmallButton(
        label: l10n.resourceDelete,
        onPressed: onAction!,
        outlined: true,
      ),
      ResourceStatus.available => _SmallButton(
        label: l10n.resourceDownload,
        onPressed: onAction!,
      ),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        border: divider ? Border(bottom: BorderSide(color: colors.line)) : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: _paddingVertical),
        child: Row(
          spacing: AppSpacing.space4,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: _mainGap,
                children: [
                  Text(title, style: _titleStyle.copyWith(color: colors.ink)),
                  status,
                ],
              ),
            ),
            end,
          ],
        ),
      ),
    );
  }
}

/// `.qk-btn-small`, and its outline variant: 44 high in a target-min hit
/// area, radius 14, padded 16 on each side.
class _SmallButton extends StatelessWidget {
  const _SmallButton({
    required this.label,
    required this.onPressed,
    this.outlined = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool outlined;

  static final BorderRadius _radius = BorderRadius.circular(_buttonRadius);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // A null background is the reference's `transparent`.
    final (Color? background, Color foreground) = outlined
        ? (null, colors.ink)
        : (colors.primary, colors.onPrimary);
    return Semantics(
      container: true,
      label: label,
      // Pressable covers the drawn face; this detector makes the rest of the
      // target-min height press it too, as in IconButton.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.targetMin),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Pressable(
              onPressed: onPressed,
              focusRadius: _radius,
              // A DecoratedBox, as the inset outline takes no layout space.
              child: ExcludeSemantics(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: _radius,
                    border: outlined
                        ? Border.all(color: colors.line, width: _outlineWidth)
                        : null,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: _buttonHeight,
                      minWidth: AppSizes.targetMin,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.space4,
                      ),
                      child: Center(
                        widthFactor: 1,
                        heightFactor: 1,
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: _smallStyle.copyWith(color: foreground),
                        ),
                      ),
                    ),
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
