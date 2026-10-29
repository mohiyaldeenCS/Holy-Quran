import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/data/services/download_service.dart';
import 'package:holyquran/data/services/pack_file_service.dart';
import 'package:holyquran/data/services/recitation_file_store.dart';
import 'package:holyquran/domain/models/recitation_file.dart';

// Every byte here is synthetic.

const _pack = 'synthetic-recitation';

final _bytes = Uint8List.fromList([for (var i = 0; i < 40; i++) i]);
final _late = Uint8List.fromList([for (var i = 0; i < 40; i++) 255 - i]);

final _file = RecitationFile(
  qualityKbps: 64,
  part: RecitationFilePart.ayah,
  surah: 1,
  ayah: 1,
  path: 'q64/1_1.mp3',
  bytes: _bytes.length,
  sha256: sha256.convert(_bytes).toString(),
  duration: null,
);

/// Writes [late] where a task that outlived its stop would, while the file
/// under check is being hashed.
final class _LateWriterFiles extends PackFileService {
  _LateWriterFiles(this.whereLate);

  final String whereLate;
  bool wrote = false;

  @override
  Future<String?> sha256Of(String path) async {
    if (!wrote) {
      wrote = true;
      await File(whereLate).writeAsBytes(_late);
    }
    return super.sha256Of(path);
  }
}

void main() {
  late Directory temp;
  late String staging;
  late String finalPath;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('recitation_file_store');
    staging = '${temp.path}/$_pack/staging';
    finalPath = '${temp.path}/$_pack/${_file.sha256}.mp3';
    await Directory(staging).create(recursive: true);
  });

  tearDown(() => temp.delete(recursive: true));

  RecitationFileStore store([PackFileService? files]) => RecitationFileStore(
    audioDirectory: () async => temp.path,
    files: files ?? const PackFileService(),
  );

  String copy(int attempt) =>
      '$staging/${FileOrder.pathAt('${_file.sha256}.mp3', attempt)}';

  Future<void> stage(int attempt, Uint8List bytes) =>
      File(copy(attempt)).writeAsBytes(bytes);

  test('gives the final name to the bytes that were checked, not to what a '
      'late writer put in staging meanwhile', () async {
    await stage(1, _bytes);
    final checked = store(_LateWriterFiles(copy(1)));

    expect(await checked.claimWhole(_pack, _file, attempt: 1), isTrue);
    await checked.activate(_pack, _file);

    expect(await File(finalPath).readAsBytes(), _bytes);
    expect(await Directory(staging).list().toList(), isEmpty);
  });

  test('finds a whole copy of any attempt, and deletes the copies that are '
      'not whole', () async {
    await stage(0, _late);
    await stage(3, _bytes);

    expect(await store().claimWhole(_pack, _file), isTrue);
    await store().activate(_pack, _file);

    expect(await File(finalPath).readAsBytes(), _bytes);
    expect(await Directory(staging).list().toList(), isEmpty);
  });

  test('looks only at the attempt it is asked about', () async {
    await stage(0, _bytes);

    expect(await store().claimWhole(_pack, _file, attempt: 2), isFalse);
    expect(await File(copy(0)).exists(), isTrue);
  });

  test(
    'tells there is nothing whole, and leaves nothing of the rest',
    () async {
      await stage(1, _late);

      expect(await store().claimWhole(_pack, _file), isFalse);
      expect(await Directory(staging).list().toList(), isEmpty);
    },
  );

  test('leaves the copies of another file alone', () async {
    final other = File('$staging/${'0' * 64}.mp3')..writeAsBytesSync(_bytes);

    expect(await store().claimWhole(_pack, _file), isFalse);
    expect(other.existsSync(), isTrue);
  });

  test('discardStaged removes every copy', () async {
    await stage(0, _bytes);
    await stage(2, _late);

    await store().discardStaged(_pack, _file);

    expect(await Directory(staging).list().toList(), isEmpty);
  });
}
