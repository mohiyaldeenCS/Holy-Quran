import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/recitation.dart';

Recitation _recitation({String id = 'a', String riwaya = 'hafs'}) => Recitation(
  id: id,
  reciter: 'Reciter A',
  riwaya: riwaya,
  style: 'Style A',
  unit: RecitationUnit.ayah,
  hasWordTiming: false,
  rightsComplete: true,
);

void main() {
  test('names its riwaya in the address form', () {
    expect(() => _recitation(riwaya: 'Hafs'), throwsArgumentError);
    expect(_recitation().riwaya, 'hafs');
  });

  test('has no basmala or isti\'adha file unless the catalogue says so', () {
    final recitation = _recitation();
    expect(recitation.hasBasmalaFile, isFalse);
    expect(recitation.hasIstiadhaFile, isFalse);
  });

  test('is identified by its id', () {
    expect(_recitation(), _recitation());
    expect(_recitation(), isNot(_recitation(id: 'b')));
  });
}
