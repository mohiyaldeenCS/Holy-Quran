import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/utils/result.dart';

import 'ayah_widget_face.dart';
import 'widget_bridge.dart';
import 'widget_fit.dart';
import 'widget_publisher.dart';
import 'widget_slots.dart';
import 'widget_test_pack.dart';

// Publishing the S4 widget with a fake bridge and a fake renderer (D-094):
// which ayat each face takes, the order of the calls, and that what reaches
// native storage holds no ayah text. The pack is synthetic.

/// A bridge that records each call; [failing] names a call that throws.
final class _FakeBridge implements WidgetBridge {
  _FakeBridge({this.failing});

  final String? failing;
  final calls = <String>[];
  final pngs = <String, Uint8List>{};
  final strings = <String, String>{};
  List<DateTime>? scheduled;

  void _record(String call) {
    calls.add(call);
    if (call == failing) throw const WidgetBridgeException('fake', false);
  }

  @override
  Future<String> savePng(String key, Uint8List png) async {
    _record('savePng');
    pngs[key] = png;
    return '/data/ayah_widget/$key.png';
  }

  @override
  Future<void> saveString(String key, String value) async {
    _record('saveString($key)');
    strings[key] = value;
  }

  @override
  Future<void> scheduleUpdates(List<DateTime> times) async {
    _record('scheduleUpdates');
    scheduled = times;
  }

  @override
  Future<void> update() async => _record('update');

  @override
  Future<bool> requestPin() async => throw UnimplementedError();

  @override
  Future<QuranAddress?> launchAddress() async => throw UnimplementedError();

  @override
  Stream<QuranAddress?> get taps => throw UnimplementedError();
}

typedef _Render = ({WidgetLook look, Size size, double quranSize, int ayah});

final _now = DateTime(2026, 10, 11, 15, 30);
const _pixelRatio = 2.5;

final _templates =
    jsonDecode(File('lib/l10n/app_ar.arb').readAsStringSync())
        as Map<String, Object?>;

void main() {
  late Directory root;
  late WidgetTestPack pack;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('s4_publisher');
    pack = await loadWidgetTestPack(root);
  });
  tearDownAll(() async {
    pack.close();
    await root.delete(recursive: true);
  });

  final renders = <_Render>[];
  Future<Uint8List> fakeRender(AyahWidgetFace face, double pixelRatio) async {
    expect(pixelRatio, _pixelRatio);
    renders.add((
      look: face.look,
      size: face.size,
      quranSize: face.quranSize,
      ayah: face.ayahNumber,
    ));
    // Distinct bytes per render, so that each image has its own digest.
    return Uint8List(face.look == WidgetLook.paper ? 3 : 5)
      ..[0] = renders.length;
  }

  setUp(renders.clear);

  Future<(Result<WidgetPublication>, _FakeBridge)> publish({
    int days = 7,
    String? failing,
  }) async {
    final bridge = _FakeBridge(failing: failing);
    final result =
        await WidgetPublisher(
          bridge,
          now: () => _now,
          render: fakeRender,
        ).publish(
          pack.ayat,
          packTextSha256: pack.textSha256,
          pixelRatio: _pixelRatio,
          days: days,
        );
    return (result, bridge);
  }

  WidgetPublication ok(Result<WidgetPublication> result) => switch (result) {
    Ok(:final value) => value,
    Failure(:final error) => fail('$error'),
  };

  test('each face takes the candidates that fit it, in order', () async {
    final (result, _) = await publish();
    final publication = ok(result);
    for (final size in WidgetFaceSize.values) {
      final box = AyahWidgetFace.ayahBoxOf(faceSizeOf(size));
      final taken = [
        for (final slot in publication.slots[size]!)
          QuranAddress.parse(slot.address),
      ];
      final skipped = publication.skipped[size]!;
      final looked = pack.ayat.take(taken.length + skipped.length).toList();
      expect(
        [...taken, ...skipped]..sort(),
        [for (final ayah in looked) ayah.address],
        reason: '$size looks at a prefix of the candidates',
      );
      for (final ayah in looked) {
        final fits = fitQuranSize(ayah.ayah, box) != null;
        expect(taken.contains(ayah.address), fits, reason: '${ayah.address}');
        expect(skipped.contains(ayah.address), !fits);
      }
      expect(taken, hasLength(lessThanOrEqualTo(7)));
    }
    final small = publication.skipped[WidgetFaceSize.small]!;
    final medium = publication.skipped[WidgetFaceSize.medium]!;
    expect(medium, isNotEmpty, reason: 'the pack holds an ayah too long');
    expect(small.length, greaterThan(medium.length));
  });

  test('a slot starts at each local midnight from today', () async {
    final (result, bridge) = await publish(days: 3);
    final publication = ok(result);
    final starts = [
      for (var day = 0; day < 3; day++)
        DateTime(2026, 10, 11 + day).millisecondsSinceEpoch,
    ];
    for (final size in WidgetFaceSize.values) {
      final slots = publication.slots[size]!;
      expect(slots, hasLength(3));
      expect([for (final slot in slots) slot.slotStartMs], starts);
    }
    expect(bridge.scheduled, [
      for (final ms in starts) DateTime.fromMillisecondsSinceEpoch(ms),
    ]);
  });

  test('renders both looks of each slot at its fitted size', () async {
    final (result, _) = await publish();
    final publication = ok(result);
    var at = 0;
    for (final size in WidgetFaceSize.values) {
      final box = AyahWidgetFace.ayahBoxOf(faceSizeOf(size));
      for (final slot in publication.slots[size]!) {
        final address = QuranAddress.parse(slot.address);
        final ayah = pack.ayat.singleWhere((a) => a.address == address);
        final expected = fitQuranSize(ayah.ayah, box);
        for (final look in [WidgetLook.paper, WidgetLook.night]) {
          expect(renders[at++], (
            look: look,
            size: faceSizeOf(size),
            quranSize: expected,
            ayah: address.ayah,
          ));
        }
        expect(slot.lightBytes, 3);
        expect(slot.darkBytes, 5);
        expect(slot.renderMs, greaterThanOrEqualTo(0));
        expect(slot.packTextSha256, pack.textSha256);
      }
    }
    expect(renders, hasLength(at));
  });

  test('calls PNGs, slots, labels, schedule, then update', () async {
    final (result, bridge) = await publish();
    final publication = ok(result);
    final images = publication.slots.values.fold(
      0,
      (sum, slots) => sum + 2 * slots.length,
    );
    expect(bridge.calls, [
      for (var i = 0; i < images; i++) 'savePng',
      'saveString(ayah_widget_slots_medium)',
      'saveString(ayah_widget_slots_small)',
      'saveString(ayah_widget_labels)',
      'scheduleUpdates',
      'update',
    ]);
  });

  test('the stored slots name the saved images', () async {
    final (result, bridge) = await publish();
    final publication = ok(result);
    for (final size in WidgetFaceSize.values) {
      final stored = decodeSlots(bridge.strings[slotsKey(size)]!);
      expect(stored, publication.slots[size]);
      for (final (index, slot) in stored!.indexed) {
        final light = imageKey(size, index, night: false);
        final dark = imageKey(size, index, night: true);
        expect(slot.lightPath, '/data/ayah_widget/$light.png');
        expect(slot.darkPath, '/data/ayah_widget/$dark.png');
        expect(bridge.pngs[light], hasLength(3));
        expect(bridge.pngs[dark], hasLength(5));
        expect(
          slot.lightSha256,
          sha256.convert(bridge.pngs[light]!).toString(),
        );
        expect(slot.darkSha256, sha256.convert(bridge.pngs[dark]!).toString());
      }
    }
  });

  test('labels are the ARB template with the whole name', () async {
    final (result, bridge) = await publish();
    final publication = ok(result);
    final template = _templates['surahTitleAyahReference']! as String;
    final labels =
        jsonDecode(bridge.strings[labelsKey]!) as Map<String, Object?>;
    final shown = {
      for (final slots in publication.slots.values)
        for (final slot in slots) slot.address,
    };
    expect(labels.keys.toSet(), shown);
    for (final MapEntry(:key, :value) in labels.entries) {
      final address = QuranAddress.parse(key);
      final name = pack.ayat
          .singleWhere((a) => a.address == address)
          .surahName
          .verbatim;
      expect(
        value,
        template
            .replaceFirst('{name}', name)
            .replaceFirst('{ayah}', arabicDigits(address.ayah)),
      );
    }
  });

  test('stored strings hold addresses, paths, digests and keys only', () async {
    final (_, bridge) = await publish();
    final ascii = RegExp(r'^[\x20-\x7e]*$');
    final allowed = RegExp(
      r'^([a-z][a-z0-9_]*:[1-9][0-9]*:[1-9][0-9]*'
      r'|/[A-Za-z0-9_./-]+\.png'
      r'|[0-9a-f]{64}'
      r'|address|slotStartMs|lightPath|darkPath|packTextSha256'
      r'|lightBytes|darkBytes|lightSha256|darkSha256|renderMs)$',
    );
    final ayahTexts = [for (final ayah in pack.ayat) ayah.ayah.verbatim];
    for (final MapEntry(:key, :value) in bridge.strings.entries) {
      for (final text in ayahTexts) {
        expect(value.contains(text), isFalse, reason: key);
      }
      if (key == labelsKey) {
        final labels = jsonDecode(value) as Map<String, Object?>;
        for (final address in labels.keys) {
          expect(address, matches(allowed));
        }
        continue;
      }
      expect(value, matches(ascii), reason: key);
      final strings = <String>[];
      void collect(Object? json) => switch (json) {
        final String s => strings.add(s),
        final List<Object?> list => list.forEach(collect),
        final Map<String, Object?> map => map.forEach((k, v) {
          strings.add(k);
          collect(v);
        }),
        _ => null,
      };
      collect(jsonDecode(value));
      for (final string in strings) {
        expect(string, matches(allowed), reason: key);
      }
    }
  });

  test('a failed call stops the publish and is named', () async {
    for (final call in [
      'savePng',
      'saveString(ayah_widget_slots_small)',
      'saveString(ayah_widget_labels)',
      'scheduleUpdates',
      'update',
    ]) {
      final (result, bridge) = await publish(failing: call);
      switch (result) {
        case Ok():
          fail('$call did not fail the publish');
        case Failure(:final error):
          expect(error, isA<WidgetPublishFailure>());
          expect((error as WidgetPublishFailure).call, startsWith(call));
          expect(error.cause, isA<WidgetBridgeException>());
      }
      expect(bridge.calls.last, call);
    }
  });

  test('a failed render is named', () async {
    final result = await WidgetPublisher(
      _FakeBridge(),
      now: () => _now,
      render: (_, _) async => throw Exception('no image'),
    ).publish(pack.ayat, packTextSha256: pack.textSha256, pixelRatio: 1);
    expect(
      result,
      isA<Failure<WidgetPublication>>().having(
        (f) => (f.error as WidgetPublishFailure).call,
        'call',
        'renderFacePng',
      ),
    );
  });

  test('refuses a malformed digest and a word candidate', () async {
    final publisher = WidgetPublisher(_FakeBridge(), render: fakeRender);
    await expectLater(
      publisher.publish(pack.ayat, packTextSha256: 'AB', pixelRatio: 1),
      throwsArgumentError,
    );
    final word = (
      address: QuranAddress('hafs', 1, 1, 1),
      ayah: pack.ayat.first.ayah,
      surahName: pack.ayat.first.surahName,
    );
    await expectLater(
      publisher.publish([word], packTextSha256: pack.textSha256, pixelRatio: 1),
      throwsArgumentError,
    );
  });

  group('renderFacePng', () {
    testWidgets('disposes every render object it creates', (tester) async {
      final ayah = pack.ayat.first;
      final face = AyahWidgetFace(
        ayah: ayah.ayah,
        surahName: ayah.surahName,
        ayahNumber: ayah.address.ayah,
        quranSize: 22,
        look: WidgetLook.paper,
        size: faceSizeOf(WidgetFaceSize.small),
      );
      final live = <Object>{};
      var created = 0;
      void track(ObjectEvent event) {
        if (event.object is! RenderObject && event.object is! PipelineOwner) {
          return;
        }
        switch (event) {
          case ObjectCreated():
            created++;
            live.add(event.object);
          case ObjectDisposed():
            live.remove(event.object);
        }
      }

      FlutterMemoryAllocations.instance.addListener(track);
      try {
        await tester.runAsync(() => renderFacePng(face, 1));
      } finally {
        FlutterMemoryAllocations.instance.removeListener(track);
      }
      expect(created, greaterThan(3));
      expect(live, isEmpty);
    });

    for (final size in WidgetFaceSize.values) {
      for (final look in WidgetLook.values) {
        testWidgets(
          'draws the ${size.name} face in ${look.name} at the pixel ratio',
          (tester) async {
            final ayah = pack.ayat.first;
            final faceSize = faceSizeOf(size);
            final face = AyahWidgetFace(
              ayah: ayah.ayah,
              surahName: ayah.surahName,
              ayahNumber: ayah.address.ayah,
              quranSize: 22,
              look: look,
              size: faceSize,
            );
            final pixels = await tester.runAsync(() async {
              final png = await renderFacePng(face, _pixelRatio);
              expect(png.sublist(1, 4), ascii.encode('PNG'));
              final header = ByteData.sublistView(png, 16, 24);
              expect(
                header.getUint32(0),
                (faceSize.width * _pixelRatio).round(),
              );
              expect(
                header.getUint32(4),
                (faceSize.height * _pixelRatio).round(),
              );
              final codec = await ui.instantiateImageCodec(png);
              final image = (await codec.getNextFrame()).image;
              codec.dispose();
              final raw = await image.toByteData();
              final width = image.width;
              image.dispose();
              return (raw!, width);
            });
            final (raw, width) = pixels!;
            // Inside the 10 px padding band (Share.dc.html line 89).
            const band = 5 * _pixelRatio;
            final at = (band.round() * width + band.round()) * 4;
            final ground = switch (look) {
              WidgetLook.paper => AppColors.paper.ground,
              WidgetLook.night => AppColors.night.ground,
            };
            expect(
              Color.fromARGB(
                raw.getUint8(at + 3),
                raw.getUint8(at),
                raw.getUint8(at + 1),
                raw.getUint8(at + 2),
              ),
              ground,
            );
          },
        );
      }
    }
  });
}
