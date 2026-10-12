import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/data/repositories/recitation_repository.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/recitation_file.dart';
import 'package:holyquran/utils/result.dart';

import '../../../testing/fakes/fake_catalogue_repository.dart';
import '../../../testing/fakes/fake_recitation_repository.dart';

void main() {
  test('lists what the test sets and notifies', () {
    final fake = FakeRecitationRepository();
    addTearDown(fake.dispose);
    var notified = 0;
    fake.addListener(() => notified++);
    expect(fake.recitations, isEmpty);
    final listed = syntheticCatalogue().listedRecitations;
    fake.recitations = listed;
    expect(fake.recitations, listed);
    expect(notified, 1);
  });

  test('answers and logs both file calls', () async {
    final fake = FakeRecitationRepository();
    addTearDown(fake.dispose);
    expect(
      await fake.surahFile('synthetic-listed', 1, qualityKbps: 64),
      isA<Failure<RecitationAudio>>().having(
        (f) => f.error,
        'error',
        isA<RecitationNotListed>(),
      ),
    );
    final audio = RecitationAudio(
      file: RecitationFile(
        qualityKbps: 64,
        part: RecitationFilePart.ayah,
        surah: 1,
        ayah: 2,
        path: 'synthetic/1-2.mp3',
        bytes: 1,
        sha256: syntheticHash(),
        duration: null,
      ),
      uri: Uri.parse('https://example.invalid/synthetic/1-2.mp3'),
      local: false,
    );
    fake.answers = (_, _, _, _) => Ok(audio);
    final result = await fake.ayahFile(
      'synthetic-listed',
      QuranAddress('hafs', 1, 2),
      qualityKbps: 128,
    );
    expect((result as Ok<RecitationAudio>).value, same(audio));
    expect(fake.calls, [
      ('synthetic-listed', 1, null, 64),
      ('synthetic-listed', 1, 2, 128),
    ]);
  });
}
