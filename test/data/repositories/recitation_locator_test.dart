import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/data/repositories/download_settings_repository.dart';
import 'package:holyquran/data/repositories/recitation_locator.dart';
import 'package:holyquran/data/repositories/recitation_repository.dart';
import 'package:holyquran/domain/models/playback_segment.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/recitation_file.dart';
import 'package:holyquran/utils/result.dart';

import '../../../testing/fakes/fake_catalogue_repository.dart';
import '../../../testing/fakes/fake_recitation_repository.dart';

// The recitation repository is a fake that says which qualities are on the
// device; the locator picks among them.

const _id = 'synthetic-listed';
final _ayah = QuranAddress('hafs', 1, 1);

RecitationAudio _audio(int quality, {required bool local}) => RecitationAudio(
  file: RecitationFile(
    qualityKbps: quality,
    part: RecitationFilePart.ayah,
    surah: 1,
    ayah: 1,
    path: 'q$quality/1_1.mp3',
    bytes: 1,
    sha256: syntheticHash(),
    duration: null,
  ),
  uri: Uri.parse(
    local ? 'file:///synthetic/q$quality' : 'https://example.invalid/q$quality',
  ),
  local: local,
);

void main() {
  late FakeRecitationRepository recitations;
  late InMemoryDownloadSettingsRepository settings;
  late Set<int> onDevice;

  setUp(() {
    recitations = FakeRecitationRepository(syntheticCatalogue().recitations)
      ..answers = (id, surah, ayah, quality) =>
          Ok(_audio(quality, local: onDevice.contains(quality)));
    settings = InMemoryDownloadSettingsRepository();
    onDevice = {};
  });

  Future<Uri?> locate({PlaybackSource? source}) async {
    final recitation = recitations.recitations.first.recitation;
    final found = await recitationLocator(
      recitations: recitations,
      settings: settings,
    )(recitation, source ?? AyahFile(_ayah));
    return found?.uri;
  }

  test('plays the chosen quality from the device when it is there', () async {
    settings = InMemoryDownloadSettingsRepository(qualities: {_id: 64});
    onDevice = {64, 128};

    expect(await locate(), Uri.parse('file:///synthetic/q64'));
  });

  test('plays the highest quality when none was chosen', () async {
    onDevice = {64, 128};

    expect(await locate(), Uri.parse('file:///synthetic/q128'));
  });

  test('falls back to a quality that is downloaded', () async {
    settings = InMemoryDownloadSettingsRepository(qualities: {_id: 128});
    onDevice = {64};

    expect(await locate(), Uri.parse('file:///synthetic/q64'));
  });

  test('streams the chosen quality when none is downloaded', () async {
    settings = InMemoryDownloadSettingsRepository(qualities: {_id: 64});

    final recitation = recitations.recitations.first.recitation;
    final found = await recitationLocator(
      recitations: recitations,
      settings: settings,
    )(recitation, AyahFile(_ayah));

    expect(found?.uri, Uri.parse('https://example.invalid/q64'));
    expect(found?.streamed, isTrue);
  });

  test('finds a surah file for a surah segment', () async {
    onDevice = {128};

    expect(
      await locate(source: const SurahFile(1)),
      Uri.parse('file:///synthetic/q128'),
    );
    expect(recitations.calls.single.$3, isNull);
  });

  test('finds nothing when the recitation has no such file', () async {
    recitations.answers = (id, _, _, _) => Failure(RecitationNotListed(id));

    expect(await locate(), isNull);
  });

  test(
    'finds nothing for the reciter\'s own basmala, which is not served yet',
    () async {
      expect(await locate(source: const BasmalaFile()), isNull);
    },
  );
}
