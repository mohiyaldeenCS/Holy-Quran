import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/quran_address.dart';

import 'gesture_target.dart';

void main() {
  final ayah = QuranAddress('hafs', 1, 1);
  QuranAddress word(int n) => QuranAddress('hafs', 1, 1, n);

  test('targets are equal by kind and address, and only then', () {
    expect(WordTarget(word(1)), WordTarget(word(1)));
    expect(WordTarget(word(1)).hashCode, WordTarget(word(1)).hashCode);
    expect(WordTarget(word(1)), isNot(WordTarget(word(2))));
    expect(WaqfMarkTarget(ayah, 1), WaqfMarkTarget(ayah, 1));
    expect(WaqfMarkTarget(ayah, 1), isNot(WaqfMarkTarget(ayah, 2)));
    expect(
      WaqfMarkTarget(ayah, 1),
      isNot(WaqfMarkTarget(QuranAddress('hafs', 1, 2), 1)),
    );
    expect(MarkerTarget(ayah), MarkerTarget(ayah));
    expect(MarkerTarget(ayah), isNot(WaqfMarkTarget(ayah, 1)));
    expect(const MarginTarget(), const MarginTarget());
    expect({
      WordTarget(word(1)),
      WordTarget(word(1)),
      const MarginTarget(),
    }, hasLength(2));
  });

  test('targets print addresses and numbers only', () {
    expect(WordTarget(word(3)).toString(), 'WordTarget(hafs:1:1:3)');
    expect(WaqfMarkTarget(ayah, 2).toString(), 'WaqfMarkTarget(hafs:1:1, 2)');
    expect(MarkerTarget(ayah).toString(), 'MarkerTarget(hafs:1:1)');
    expect(const MarginTarget().toString(), 'MarginTarget()');
  });

  test('a switch over a target is exhaustive without a default', () {
    String kind(GestureTarget target) => switch (target) {
      WordTarget() => 'word',
      WaqfMarkTarget() => 'mark',
      MarkerTarget() => 'marker',
      MarginTarget() => 'margin',
    };
    expect(
      [
        WordTarget(word(1)),
        WaqfMarkTarget(ayah, 1),
        MarkerTarget(ayah),
        const MarginTarget(),
      ].map(kind),
      ['word', 'mark', 'marker', 'margin'],
    );
  });
}
