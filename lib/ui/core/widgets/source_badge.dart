import 'package:flutter/widgets.dart' hide Icon;

import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/icon.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/core/widgets/pressable.dart';
import 'package:holyquran/ui/core/widgets/tafsir_text.dart';

/// The source badge of PRD §7.7: the name of the source and its version
/// under non-Quran material (`LX-11`, `TF-05`), in `caption` and `accent`
/// beside the `info` icon, which takes the `info` colour (tokens.md: «معلومة:
/// مصدر البيانات»). Pressing it opens the source's details through
/// [onPressed]. It stands at least 48 high, whatever the caption's size.
///
/// [name] is the book's title from its pack; it is drawn by [TafsirText] and
/// wraps rather than being cut.
class SourceBadge extends StatelessWidget {
  const SourceBadge({
    required this.name,
    required this.version,
    required this.onPressed,
    super.key,
  });

  final PackText name;
  final int version;
  final VoidCallback onPressed;

  static final BorderRadius _radius = BorderRadius.circular(AppRadius.radiusSm);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final style = AppTextStyles.caption.copyWith(
      inherit: false,
      color: colors.accent,
    );
    return Semantics(
      container: true,
      child: Pressable(
        onPressed: onPressed,
        focusRadius: _radius,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.targetMin),
          child: Row(
            spacing: AppSpacing.space2,
            children: [
              Icon(IconName.info, color: colors.info),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: style,
                    children: [
                      TafsirText.span(name, style: style),
                      TextSpan(
                        text:
                            '${l10n.dataSeparator}'
                            '${l10n.sourceVersion(arabicDigits(version))}',
                      ),
                    ],
                  ),
                  textDirection: TextDirection.rtl,
                  locale: const Locale('ar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
