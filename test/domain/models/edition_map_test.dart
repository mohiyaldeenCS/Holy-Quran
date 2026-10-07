import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/edition_map.dart';
import 'package:holyquran/domain/models/quran_address.dart';

QuranAddress _a(String source) => QuranAddress.parse(source);

EditionMap _map({
  Map<Division, List<QuranAddress>>? starts,
  Set<QuranAddress>? sajdas,
}) => EditionMap(
  edition: 'synthetic-edition',
  starts:
      starts ??
      {
        Division.juz: [_a('x:1:1'), _a('x:2:5'), _a('x:3:1')],
        Division.page: [_a('x:1:1'), _a('x:1:4'), _a('x:2:1'), _a('x:2:5')],
      },
  sajdas: sajdas ?? {_a('x:2:3'), _a('x:3:2')},
);

void main() {
  test('keeps its edition and counts each division', () {
    final map = _map();
    expect(map.edition, 'synthetic-edition');
    expect(map.count(Division.juz), 3);
    expect(map.count(Division.page), 4);
    expect(map.count(Division.hizb), 0, reason: 'absent division');
    expect(map.sajdas, {_a('x:2:3'), _a('x:3:2')});
  });

  group('numberAt', () {
    final map = _map();

    test('finds the unit holding an ayah, at and between boundaries', () {
      expect(map.numberAt(Division.juz, _a('x:1:1')), 1);
      expect(map.numberAt(Division.juz, _a('x:2:4')), 1);
      expect(map.numberAt(Division.juz, _a('x:2:5')), 2);
      expect(map.numberAt(Division.juz, _a('x:2:99')), 2);
      expect(map.numberAt(Division.juz, _a('x:3:1')), 3);
      expect(map.numberAt(Division.juz, _a('x:9:9')), 3);
      expect(map.numberAt(Division.page, _a('x:1:3')), 1);
      expect(map.numberAt(Division.page, _a('x:1:4')), 2);
      expect(map.numberAt(Division.page, _a('x:2:1')), 3);
    });

    test('uses the ayah of a word address', () {
      expect(map.numberAt(Division.juz, _a('x:2:5:1')), 2);
      expect(map.numberAt(Division.juz, _a('x:2:4:9')), 1);
    });

    test('throws for an ayah before the first unit or an absent division', () {
      final late = _map(
        starts: {
          Division.rub: [_a('x:1:3'), _a('x:2:1')],
        },
      );
      expect(
        () => late.numberAt(Division.rub, _a('x:1:2')),
        throwsArgumentError,
      );
      expect(map.numberAt(Division.juz, _a('x:1:1')), 1);
      expect(
        () => map.numberAt(Division.hizb, _a('x:1:1')),
        throwsArgumentError,
      );
    });

    test('throws for an address in another riwaya', () {
      expect(
        () => map.numberAt(Division.juz, _a('y:2:5')),
        throwsArgumentError,
      );
    });
  });

  group('startOf', () {
    final map = _map();

    test('returns the first ayah of each unit', () {
      expect(map.startOf(Division.juz, 1), _a('x:1:1'));
      expect(map.startOf(Division.juz, 2), _a('x:2:5'));
      expect(map.startOf(Division.juz, 3), _a('x:3:1'));
      for (var number = 1; number <= map.count(Division.page); number++) {
        final start = map.startOf(Division.page, number);
        expect(map.numberAt(Division.page, start), number);
      }
    });

    test('throws a RangeError outside 1..count', () {
      expect(() => map.startOf(Division.juz, 0), throwsRangeError);
      expect(() => map.startOf(Division.juz, 4), throwsRangeError);
      expect(() => map.startOf(Division.juz, -1), throwsRangeError);
      expect(() => map.startOf(Division.hizb, 1), throwsRangeError);
    });
  });

  test('isSajda answers for the ayah of any address', () {
    final map = _map();
    expect(map.isSajda(_a('x:2:3')), isTrue);
    expect(map.isSajda(_a('x:2:3:4')), isTrue);
    expect(map.isSajda(_a('x:3:2')), isTrue);
    expect(map.isSajda(_a('x:2:4')), isFalse);
    expect(map.isSajda(_a('y:2:3')), isFalse);
  });

  group('constructor rejects', () {
    test('starts that are not strictly increasing', () {
      expect(
        () => _map(
          starts: {
            Division.juz: [_a('x:1:1'), _a('x:2:1'), _a('x:2:1')],
          },
        ),
        throwsArgumentError,
      );
      expect(
        () => _map(
          starts: {
            Division.page: [_a('x:1:1'), _a('x:2:1'), _a('x:1:9')],
          },
        ),
        throwsArgumentError,
      );
    });

    test('a word address as a start or a sajda', () {
      expect(
        () => _map(
          starts: {
            Division.hizb: [_a('x:1:1'), _a('x:2:1:2')],
          },
        ),
        throwsArgumentError,
      );
      expect(() => _map(sajdas: {_a('x:2:3:1')}), throwsArgumentError);
    });

    test('addresses in more than one riwaya', () {
      expect(
        () => _map(
          starts: {
            Division.juz: [_a('x:1:1')],
            Division.page: [_a('y:1:1')],
          },
        ),
        throwsArgumentError,
      );
      expect(() => _map(sajdas: {_a('y:2:3')}), throwsArgumentError);
    });
  });

  test('is not changed by later edits to its inputs', () {
    final juz = [_a('x:1:1'), _a('x:2:1')];
    final sajdas = {_a('x:2:3')};
    final map = _map(starts: {Division.juz: juz}, sajdas: sajdas);
    juz.add(_a('x:3:1'));
    sajdas.add(_a('x:3:2'));
    expect(map.count(Division.juz), 2);
    expect(map.isSajda(_a('x:3:2')), isFalse);
    expect(() => map.sajdas.add(_a('x:4:1')), throwsUnsupportedError);
  });
}
