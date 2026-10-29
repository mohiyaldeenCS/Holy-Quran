import 'package:holyquran/domain/models/category.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/widgets/tag.dart';

/// The shape a built-in category has in [Tag] (`Tag/README.md`): the ribbon
/// carries the category in this shape (`AX-05`).
TagShape ribbonShapeOf(BuiltinCategory category) => switch (category) {
  BuiltinCategory.memorise => TagShape.circle,
  BuiltinCategory.review => TagShape.square,
  BuiltinCategory.study => TagShape.diamond,
  BuiltinCategory.important => TagShape.ring,
};

/// The category's name, as the identity's `Tag` preview writes it.
String ribbonCategoryName(AppLocalizations l10n, BuiltinCategory category) =>
    switch (category) {
      BuiltinCategory.memorise => l10n.tagMemorise,
      BuiltinCategory.review => l10n.tagReview,
      BuiltinCategory.study => l10n.tagStudy,
      BuiltinCategory.important => l10n.tagImportant,
    };
