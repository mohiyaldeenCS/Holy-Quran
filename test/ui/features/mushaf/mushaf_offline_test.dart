import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/pack_integrity.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/ui/core/widgets/quran_text.dart';
import 'package:holyquran/ui/features/mushaf/view_models/mushaf_view_model.dart';
import 'package:holyquran/utils/result.dart';

import 'mushaf_harness.dart';
import 'provided_pack_harness.dart';

/// Any attempt to reach the network.
final class _NoNetwork extends HttpOverrides {
  int attempts = 0;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    attempts++;
    throw StateError('The reader used the network.');
  }
}

void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('mushaf_offline'));
  tearDown(() => root.deleteSync(recursive: true));

  testWidgets('reads the bundled pack on the first run with no network', (
    tester,
  ) async {
    final network = _NoNetwork();
    final before = HttpOverrides.current;
    HttpOverrides.global = network;
    addTearDown(() => HttpOverrides.global = before);
    expect(Directory('${root.path}/support').existsSync(), isFalse);

    final pack = (await tester.runAsync(() => ProvidedPack.load(root)))!;
    addTearDown(pack.close);
    expect(pack.integrity.stateOf(ProvidedPack.packId), isA<IntegrityOk>());
    expect(pack.support.existsSync(), isTrue);

    setReaderView(tester);
    final semantics = tester.ensureSemantics();
    final viewModel = pack.viewModel();
    addTearDown(viewModel.dispose);
    await tester.pumpWidget(readerApp(viewModel));
    await tester.pumpAndSettle();

    expect(viewModel.status, ReaderStatus.ready);
    expect(viewModel.surahs, isNotEmpty);
    final labels = await labelsFromScrollingToEnd(
      tester,
      viewModel,
      lastSurah: pack.index!.surahCount,
    );
    final first = await pack.text!.ayahText(QuranAddress('hafs', 1, 1));
    expect(labels, contains((first as Ok<PackText>).value.verbatim));
    expect(find.byType(QuranText), findsWidgets);
    expect(network.attempts, 0);
    semantics.dispose();
  });
}
