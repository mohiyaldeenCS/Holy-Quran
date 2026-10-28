import 'package:flutter/widgets.dart';

import 'package:holyquran/domain/models/category.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/ramps.g.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/widgets/tag.dart';

/// The word of [category], as the identity's `Tag` preview names it.
String categoryName(BuiltinCategory category, AppLocalizations l10n) =>
    switch (category) {
      BuiltinCategory.memorise => l10n.tagMemorise,
      BuiltinCategory.review => l10n.tagReview,
      BuiltinCategory.study => l10n.tagStudy,
      BuiltinCategory.important => l10n.tagImportant,
    };

/// A built-in category as a [Tag] (D-128, 9): its shape from
/// `components/Tag/README.md` (`circle` حفظ, `square` مراجعة, `diamond` دراسة,
/// `ring` آيات مهمة), its fixed colour from `Tag/preview.html` (`emerald-700`,
/// `gold-600`, `info`, `error`), the same in every theme, and its word.
class CategoryTag extends StatelessWidget {
  const CategoryTag({
    required this.category,
    required this.selected,
    required this.onPressed,
    super.key,
  });

  final BuiltinCategory category;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (shape, color) = switch (category) {
      BuiltinCategory.memorise => (TagShape.circle, Ramps.emerald700),
      BuiltinCategory.review => (TagShape.square, Ramps.gold600),
      BuiltinCategory.study => (TagShape.diamond, colors.info),
      BuiltinCategory.important => (TagShape.ring, colors.error),
    };
    return Tag(
      label: categoryName(category, AppLocalizations.of(context)),
      shape: shape,
      color: color,
      selected: selected,
      onPressed: onPressed,
    );
  }
}

/// A free tag (`UD-02`) as a [Tag]. The identity gives no shape or colour to
/// free tags; they take the hollow `ring` in `ink-muted`, so that no category
/// colour is borrowed, and the name carries the meaning.
class FreeTag extends StatelessWidget {
  const FreeTag({
    required this.name,
    required this.selected,
    required this.onPressed,
    super.key,
  });

  final String name;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Tag(
    label: name,
    shape: TagShape.ring,
    color: context.colors.inkMuted,
    selected: selected,
    onPressed: onPressed,
  );
}
