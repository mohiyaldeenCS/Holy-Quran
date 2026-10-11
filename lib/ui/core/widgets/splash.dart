import 'package:flutter/widgets.dart';

import 'package:holyquran/ui/core/theme/ramps.g.dart';
import 'package:holyquran/ui/core/widgets/lockup.dart';

/// The splash screen (Share.dc.html, «شاشة البداية»): the horizontal lockup
/// centred on emerald, with no loading indicator. Fixed brand colours in
/// every theme, so it does not turn gold at night.
final class Splash extends StatelessWidget {
  const Splash({super.key});

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Ramps.emerald700,
    child: Center(child: Lockup(size: _lockupSize, onEmerald: true)),
  );
}

// Share.dc.html, splash: `<svg width="64" height="64">` beside the name at
// `font-size:32px`, `gap:12px`: Lockup at 64, whose name is half its size.
const double _lockupSize = 64;
