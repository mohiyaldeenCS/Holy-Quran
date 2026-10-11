import 'package:flutter/widgets.dart';

import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';

/// One titled section of the debug gallery: the title, a header for screen
/// readers, over the samples.
class GallerySection extends StatelessWidget {
  const GallerySection({required this.title, required this.child, super.key});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: AppSpacing.space3,
    children: [
      Semantics(
        header: true,
        child: Text(
          title,
          style: AppTextStyles.bodyStrong.copyWith(
            color: context.colors.inkMuted,
          ),
        ),
      ),
      child,
    ],
  );
}

/// The previews' `.qk-row`: a wrapping row, space-3 apart, centred across.
Widget galleryRow(List<Widget> children) => Wrap(
  spacing: AppSpacing.space3,
  runSpacing: AppSpacing.space3,
  crossAxisAlignment: WrapCrossAlignment.center,
  children: children,
);

/// The emerald surface the previews draw the brand variants on
/// (Mark/preview.html, Lockup/preview.html): a fixed brand [color], radius 24.
class GalleryBackdrop extends StatelessWidget {
  const GalleryBackdrop({
    required this.color,
    required this.child,
    this.padding = AppSpacing.space2,
    super.key,
  });

  final Color color;
  final double padding;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(AppRadius.radiusCard),
    ),
    child: Padding(padding: EdgeInsets.all(padding), child: child),
  );
}
