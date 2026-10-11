import 'package:flutter/widgets.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/ramps.g.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/icon_button.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/core/widgets/mark.dart';

/// The home screen's header (Screens.dc.html, the home board): the app-icon
/// tile and the app's name at the start, the search button at the end.
/// The search button is shown only when [onSearch] is given.
final class HomeHeader extends StatelessWidget {
  const HomeHeader({this.onSearch, super.key});

  final VoidCallback? onSearch;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final onSearch = this.onSearch;
    return Row(
      children: [
        const AppIconTile(),
        const SizedBox(width: _titleGap),
        Expanded(
          child: Text(
            l10n.appTitle,
            style: AppTextStyles.appTitle.copyWith(
              color: context.colors.brandInk,
            ),
          ),
        ),
        if (onSearch != null)
          IconButton(
            icon: IconName.search,
            label: l10n.homeSearch,
            tone: IconButtonTone.tint,
            onPressed: onSearch,
          ),
      ],
    );
  }
}

/// The app icon as the home header draws it: the emerald `Mark` on a rounded
/// emerald tile, in fixed brand colours whatever the theme.
final class AppIconTile extends StatelessWidget {
  const AppIconTile({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    image: true,
    label: AppLocalizations.of(context).appIconLabel,
    child: Container(
      width: _tileSize,
      height: _tileSize,
      decoration: BoxDecoration(
        color: Ramps.emerald700,
        borderRadius: BorderRadius.circular(_tileRadius),
      ),
      child: const Mark(
        size: _tileSize,
        variant: MarkVariant.emerald,
        decorative: true,
      ),
    ),
  );
}

// Screens.dc.html, home header: `<svg width="40" height="40" viewBox="0 0 120
// 120">` whose `<rect width="120" height="120" rx="28">` is the tile and
// whose star and book fill the same viewBox, so the mark is as large as the
// tile.
const double _tileSize = 40;
const double _tileRadius = 28 * _tileSize / 120;

// Screens.dc.html, home header: the tile and the name sit `gap:10px` apart.
const double _titleGap = 10;
