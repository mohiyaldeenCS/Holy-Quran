import 'package:flutter/widgets.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/surah_name.dart';

/// A stand-in for the waqf card a mark tap opens (PRD §7.4): the ayah's
/// reference through [SurahName] and the mark's number as a debug line.
/// Nothing else: the mark's glyph would need a slice of the stored text
/// (D-062), and its meaning, name and abbreviation have no `Ready` source
/// (registry row 19, B0.8), so those fields are hidden.
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
        border: Border.all(color: colors.line),
        borderRadius: BorderRadius.circular(AppRadius.radiusCard),
        boxShadow: context.shadows.shadowCard,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.space2,
          children: [
            SurahName(
              surahName,
              format: SurahNameFormat.withAyah,
              ayah: ayah.ayah,
              style: AppTextStyles.bodyStrong.copyWith(color: colors.ink),
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
    );
  }
}
