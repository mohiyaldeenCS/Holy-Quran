import 'package:flutter/widgets.dart';

import 'interactive_surah_sliver.dart';
import 'surah_layout.dart';
import 'surah_text.dart';

/// A surah in surah mode as a sliver (`RD-02`) with no gestures: the basmala
/// on its own centred line when the surah shows one, then the text in blocks,
/// each laid out only when it comes near the screen. It is
/// [InteractiveSurahSliver] with nothing listening (D-141, 3).
///
/// The text is set at reader step [step] on top of the system text scale
/// (`RD-07`). [onLayout] hears each new plan, after the frame that made it.
final class SurahSliver extends StatelessWidget {
  const SurahSliver({
    required this.text,
    this.step = 1,
    this.onLayout,
    super.key,
  });

  final SurahText text;
  final double step;
  final ValueChanged<SurahLayout>? onLayout;

  @override
  Widget build(BuildContext context) =>
      InteractiveSurahSliver(text: text, step: step, onLayout: onLayout);
}
