@Tags(['golden'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/ui/core/theme/ramps.g.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/quran_text.dart';

import '../../../../testing/golden.dart';

// Synthetic, never Quran text.
const _sample = PackText.fromPack('نص تجريبي للاختبار');
const _long = PackText.fromPack(
  'نص تجريبي للاختبار يمتد على أكثر من سطر واحد ليظهر الضبط',
);

void main() {
  testWidgets('QuranText sizes and alignments', (tester) async {
    await expectGoldensInThemes(
      tester,
      'quran_text',
      (context) => const SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            QuranText(_long),
            QuranText(_sample, align: QuranTextAlign.center),
            QuranText(_sample, size: QuranTextSize.ayah),
            QuranText(_sample, size: QuranTextSize.focus),
            QuranText(
              _sample,
              size: QuranTextSize.compact,
              align: QuranTextAlign.start,
            ),
          ],
        ),
      ),
      surfaceSize: const Size(400, 620),
    );
  });
  testWidgets('QuranText colour roles: accent, and paper-100 on emerald', (
    tester,
  ) async {
    await expectGoldensInThemes(
      tester,
      'quran_text_roles',
      (context) => SizedBox(
        width: 360,
        child: goldenColumn(const [
          QuranText(
            _sample,
            size: QuranTextSize.focus,
            align: QuranTextAlign.start,
            colour: QuranTextColour.accent,
          ),
          _Emerald(
            child: QuranText(
              _sample,
              size: QuranTextSize.ayah,
              align: QuranTextAlign.center,
              colour: QuranTextColour.onEmerald,
            ),
          ),
        ]),
      ),
      surfaceSize: const Size(400, 320),
    );
  });

  testWidgets('QuranText card at the Share board sizes', (tester) async {
    await expectGoldensInThemes(
      tester,
      'quran_text_card',
      (context) => SizedBox(
        width: 360,
        child: goldenColumn(const [
          _Emerald(
            child: QuranText.card(
              _long,
              fontSize: 34,
              colour: QuranTextColour.onEmerald,
            ),
          ),
          QuranText.card(_sample, fontSize: 26),
          QuranText.card(_sample, fontSize: 23),
        ]),
      ),
      surfaceSize: const Size(400, 560),
    );
  });
}

/// The emerald share card's ground (Share board: `emerald-700`), fixed in
/// every theme.
class _Emerald extends StatelessWidget {
  const _Emerald({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Ramps.emerald700,
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.space4),
      child: child,
    ),
  );
}
