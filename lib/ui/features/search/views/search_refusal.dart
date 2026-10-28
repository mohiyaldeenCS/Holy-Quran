import 'package:flutter/widgets.dart' hide Icon;

import 'package:holyquran/domain/models/edition_map.dart';
import 'package:holyquran/domain/models/go_to_error.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/icon.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/core/widgets/surah_name.dart';

/// The sentence that names why a typed place or scope was refused, with the
/// alert icon so that the state is not told by colour alone. [surahName]
/// gives the name of a surah in the pack.
class SearchRefusal extends StatelessWidget {
  const SearchRefusal({
    required this.error,
    required this.surahName,
    super.key,
  });

  final GoToError error;
  final PackText? Function(int surah) surahName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final style = AppTextStyles.secondary.copyWith(color: colors.error);
    final sentence = switch (error) {
      NoSuchAyah(:final surah, :final ayah) => _ayahMissing(
        l10n,
        surahName(surah),
        ayah,
        style,
      ),
      NoSuchSurah(:final surah) => Text(
        l10n.surahNumberNotFound(arabicDigits(surah)),
        style: style,
      ),
      DivisionOutOfRange(:final division, :final number) => Text(
        _divisionMissing(l10n, division, arabicDigits(number)),
        style: style,
      ),
      UnreadableGoTo() => Text(l10n.addressUnreadable, style: style),
    };
    return Semantics(
      liveRegion: true,
      container: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.space2,
        children: [
          Icon(IconName.alert, color: colors.error),
          Expanded(child: sentence),
        ],
      ),
    );
  }
}

String _divisionMissing(
  AppLocalizations l10n,
  Division division,
  String number,
) => switch (division) {
  Division.page => l10n.pageNotFound(number),
  Division.juz => l10n.juzNotFound(number),
  Division.hizb => l10n.hizbNotFound(number),
  Division.rub => l10n.rubNotFound(number),
};

// «لا توجد آية {ayah} في {surah}» with the surah's name from the pack set by
// SurahName, the only widget that draws a name (D-084), at the place the
// sentence has for it.
const String _nameSlot = '\u0000';

Widget _ayahMissing(
  AppLocalizations l10n,
  PackText? name,
  int ayah,
  TextStyle style,
) {
  if (name == null) return Text(l10n.addressUnreadable, style: style);
  final parts = l10n
      .ayahNotInSurah(arabicDigits(ayah), _nameSlot)
      .split(_nameSlot);
  return Text.rich(
    TextSpan(
      style: style,
      children: [
        TextSpan(text: parts.first),
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: SurahName(name, style: style),
        ),
        TextSpan(text: parts.last),
      ],
    ),
  );
}
