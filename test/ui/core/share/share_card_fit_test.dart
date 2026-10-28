import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/ui/core/share/share_card_fit.dart';

void main() {
  test('the ratios keep the width and take the height from the ratio', () {
    expect(ShareCardRatio.square.heightFor(300), 300);
    expect(ShareCardRatio.portrait.heightFor(300), 375);
    expect(ShareCardRatio.tall.heightFor(270), 480);
  });

  test('the card starts at 34 and shrinks to 22 at the least', () {
    expect(shareCardFontSize, 34);
    expect(shareCardLeastFontSize, 22);
  });

  test('takes the largest size that fits at the chosen ratio', () {
    for (final ratio in ShareCardRatio.values) {
      for (final largest in [34.0, 30.0, 22.0]) {
        final asked = <(ShareCardRatio, double)>[];
        final fit = fitShareCard(ratio, (r, size) {
          asked.add((r, size));
          return r == ratio && size <= largest;
        });
        expect(fit, ShareCardFits(ratio, largest));
        expect(asked.first, (ratio, 34.0));
        expect(asked.map((a) => a.$1).toSet(), {ratio});
      }
    }
  });

  test('moves to the tall card when the chosen one does not hold the ayah '
      'at 22', () {
    for (final ratio in [ShareCardRatio.square, ShareCardRatio.portrait]) {
      final asked = <(ShareCardRatio, double)>[];
      final fit = fitShareCard(ratio, (r, size) {
        asked.add((r, size));
        return r == ShareCardRatio.tall && size <= 25;
      });
      expect(fit, const ShareCardFits(ShareCardRatio.tall, 25));
      expect(asked.where((a) => a.$1 == ratio).map((a) => a.$2), [
        for (var size = 34.0; size >= 22; size--) size,
      ]);
    }
  });

  test('is too long when not even the tall card holds the ayah at 22', () {
    for (final ratio in ShareCardRatio.values) {
      final asked = <(ShareCardRatio, double)>[];
      final fit = fitShareCard(ratio, (r, size) {
        asked.add((r, size));
        return false;
      });
      expect(fit, const ShareCardTooLong());
      expect(asked.map((a) => a.$2).reduce((a, b) => a < b ? a : b), 22);
      expect(asked.last, (ShareCardRatio.tall, 22.0));
      // The tall card is tried once, however it was reached.
      expect(asked.where((a) => a.$1 == ShareCardRatio.tall), hasLength(13));
    }
  });
}
