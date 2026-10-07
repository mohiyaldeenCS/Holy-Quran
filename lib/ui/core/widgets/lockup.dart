import 'package:flutter/widgets.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/ramps.g.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/mark.dart';

/// The mark with the app's name beside it, the mark first in reading order.
/// [onEmerald] for the splash and share cards; [stacked] puts the name under
/// a larger mark.
///
/// A logotype: its name keeps its size whatever the system text scale.
final class Lockup extends StatelessWidget {
  const Lockup({
    this.size = _defaultSize,
    this.onEmerald = false,
    this.stacked = false,
    super.key,
  });

  final double size;
  final bool onEmerald;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final mark = Mark(
      size: stacked ? size * _stackedMarkScale : size,
      variant: onEmerald ? MarkVariant.emerald : MarkVariant.paper,
      decorative: true,
    );
    final name = MediaQuery.withNoTextScaling(
      child: Text(
        AppLocalizations.of(context).appTitle,
        softWrap: false,
        style: AppTextStyles.appTitle.copyWith(
          fontSize: (size * _nameScale).roundToDouble(),
          height: _nameHeight,
          color: onEmerald ? Ramps.paper100 : context.colors.brandInk,
        ),
      ),
    );
    return Flex(
      direction: stacked ? Axis.vertical : Axis.horizontal,
      mainAxisSize: MainAxisSize.min,
      spacing: stacked ? _stackedGap : AppSpacing.space3,
      children: [mark, name],
    );
  }
}

// Lockup in index.jsx: `size = 48`.
const double _defaultSize = 48;

// Lockup in index.jsx: `size={stacked ? size * 1.4 : size}`.
const double _stackedMarkScale = 1.4;

// Lockup in index.jsx: `fontSize: Math.round(size * 0.5)`.
const double _nameScale = 0.5;

// .qk-lockup-name: `line-height: 1.3`.
const double _nameHeight = 1.3;

// .qk-lockup-stacked: `gap: 2px` (the row's 12px is space-3).
const double _stackedGap = 2;
