import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/listening_position.dart';
import 'package:holyquran/domain/models/quran_address.dart';

ListeningPosition _position({
  String address = 'hafs:2:5',
  String recitationId = 'synthetic-reciter',
  int offsetMs = 1500,
}) => ListeningPosition(
  address: QuranAddress.parse(address),
  recitationId: recitationId,
  offset: Duration(milliseconds: offsetMs),
);

void main() {
  test('refuses a word address and a negative offset', () {
    expect(() => _position(address: 'hafs:2:5:1'), throwsArgumentError);
    expect(() => _position(offsetMs: -1), throwsArgumentError);
    expect(_position(offsetMs: 0).offset, Duration.zero);
  });

  test('is equal by every field', () {
    expect(_position(), _position());
    expect(_position().hashCode, _position().hashCode);
    expect(_position(), isNot(_position(address: 'hafs:2:6')));
    expect(_position(), isNot(_position(recitationId: 'other-reciter')));
    expect(_position(), isNot(_position(offsetMs: 1)));
    expect(
      '${_position()}',
      'ListeningPosition(hafs:2:5, synthetic-reciter, 0:00:01.500000)',
    );
  });
}
