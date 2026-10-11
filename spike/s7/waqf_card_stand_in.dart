import 'package:flutter/widgets.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/surah_name.dart';

// The waqf card on the Mushaf board (Mushaf.dc.html): padding 22px 24px.
const double _paddingY = 22;

/// A stand-in for the waqf card a mark tap opens (PRD §7.4), as the Mushaf
/// board draws it, on a bottom sheet as `.qk-sheet` is (`radius-sheet` at
/// the top, a `line` top border, `shadow-sheet`): the ayah's reference
/// through [SurahName] and the mark's number as a debug line. The rest of
/// the board's card is hidden: the glyph would need a slice of the stored
/// text (D-062), the title, meaning and link have no `Ready` source
/// (registry row 19, B0.8), and the handle drags nothing here.
final class WaqfCardStandIn extends StatelessWidget {
  const WaqfCardStandIn({
    required this.surahName,
    required this.ayah,
    required this.mark,
    super.key,
  });

  final PackText surahName;
  final QuranAddress ayah;
  final int mark;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.line)),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.radiusSheet),
        ),
        boxShadow: context.shadows.shadowSheet,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space5,
            vertical: _paddingY,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.space3,
            children: [
              SurahName(
                surahName,
                format: SurahNameFormat.withAyah,
                ayah: ayah.ayah,
                style: AppTextStyles.secondary.copyWith(color: colors.inkMuted),
              ),
              // Not a UI string: the spike's debug label, as in S1 (D-072).
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  'Mark $mark',
                  style: AppTextStyles.caption.copyWith(color: colors.inkMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
