import 'package:flutter/widgets.dart' hide Icon;

import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/icon.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/core/widgets/small_button.dart';

/// The alert of PRD §7.7 («تنبيه السلامة»: `error` with an icon and a word),
/// also used for «تعذّر الاتصال», which tokens.md gives to `error` too: the
/// `alert` icon in `error` beside its [title] in `error`, its [body] in
/// `ink`, and its [action] as a small outline button, like «حذف».
///
/// The words are the caller's; whichever of them is null is left out.
class IntegrityAlert extends StatelessWidget {
  const IntegrityAlert({this.title, this.body, this.action, super.key})
    : assert(title != null || body != null || action != null);

  final String? title;
  final String? body;
  final ({String label, VoidCallback onPressed})? action;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final title = this.title;
    final body = this.body;
    final action = this.action;
    return Semantics(
      container: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.space3,
        children: [
          Icon(IconName.alert, color: colors.error),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.space2,
              children: [
                if (title != null)
                  Text(
                    title,
                    style: AppTextStyles.bodyStrong.copyWith(
                      color: colors.error,
                    ),
                  ),
                if (body != null)
                  Text(
                    body,
                    style: AppTextStyles.body.copyWith(color: colors.ink),
                  ),
                if (action != null)
                  SmallButton(
                    label: action.label,
                    onPressed: action.onPressed,
                    outlined: true,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
