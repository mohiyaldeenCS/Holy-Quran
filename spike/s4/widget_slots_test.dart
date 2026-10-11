import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/quran_address.dart';

import 'widget_slots.dart';

// The keys, JSON, slot rule and link the native widget mirrors (D-094).
// Addresses and file paths only: nothing here is text.

WidgetSlotInfo _slot(int startMs, {String address = 'hafs:1:1'}) => (
  address: address,
  slotStartMs: startMs,
  lightPath: '/images/ayah_widget_medium_0_paper.png',
  darkPath: '/images/ayah_widget_medium_0_night.png',
  packTextSha256: 'ab' * 32,
  lightBytes: 10,
  darkBytes: 11,
  renderMs: 12,
);

void main() {
  group('slotStarts', () {
    test('is the local midnight of today and each following day', () {
      final starts = slotStarts(DateTime(2026, 10, 11, 15, 42, 7), 7);
      expect(starts, hasLength(7));
      for (final (day, start) in starts.indexed) {
        expect(start.isUtc, isFalse);
        expect(start, DateTime(2026, 10, 11 + day));
        expect((start.hour, start.minute, start.second), (0, 0, 0));
      }
    });

    test('starts at today when it is just after midnight', () {
      expect(slotStarts(DateTime(2026, 12, 31, 0, 0, 1), 2), [
        DateTime(2026, 12, 31),
        DateTime(2027),
      ]);
    });

    test('takes the local day of a UTC time', () {
      final now = DateTime.utc(2026, 3, 1, 12);
      final local = now.toLocal();
      expect(
        slotStarts(now, 1).single,
        DateTime(local.year, local.month, local.day),
      );
    });

    test('refuses fewer than one day', () {
      expect(() => slotStarts(DateTime(2026), 0), throwsArgumentError);
    });
  });

  group('slotAt', () {
    final slots = [_slot(1000), _slot(2000), _slot(3000)];

    test('is null when there are no slots', () {
      expect(slotAt(const [], 0), isNull);
    });

    test('is the first before any day has started', () {
      expect(slotAt(slots, 999), same(slots[0]));
      expect(slotAt(slots, -1), same(slots[0]));
    });

    test('changes exactly at each start', () {
      expect(slotAt(slots, 1000), same(slots[0]));
      expect(slotAt(slots, 1999), same(slots[0]));
      expect(slotAt(slots, 2000), same(slots[1]));
      expect(slotAt(slots, 2999), same(slots[1]));
      expect(slotAt(slots, 3000), same(slots[2]));
    });

    test('keeps the last after the last day has started', () {
      expect(slotAt(slots, 1 << 50), same(slots[2]));
    });
  });

  group('keys', () {
    final safe = RegExp(r'^[a-z0-9_]+$');
    final keys = [
      for (final size in WidgetFaceSize.values) slotsKey(size),
      labelsKey,
      for (final size in WidgetFaceSize.values)
        for (var index = 0; index < 7; index++)
          for (final night in [false, true])
            imageKey(size, index, night: night),
    ];

    test('are distinct', () {
      expect(keys.toSet(), hasLength(keys.length));
    });

    test('are safe file names', () {
      for (final key in keys) {
        expect(key, matches(safe));
      }
    });

    test('are the names the native widget reads', () {
      expect(slotsKey(WidgetFaceSize.medium), 'ayah_widget_slots_medium');
      expect(slotsKey(WidgetFaceSize.small), 'ayah_widget_slots_small');
      expect(labelsKey, 'ayah_widget_labels');
      expect(
        imageKey(WidgetFaceSize.small, 3, night: true),
        'ayah_widget_small_3_night',
      );
    });

    test('refuse a negative index', () {
      expect(
        () => imageKey(WidgetFaceSize.medium, -1, night: false),
        throwsArgumentError,
      );
    });
  });

  group('slot JSON', () {
    test('round-trips', () {
      final slots = [_slot(1000), _slot(2000, address: 'hafs:2:3')];
      expect(decodeSlots(encodeSlots(slots)), slots);
      expect(decodeSlots(encodeSlots(const [])), isEmpty);
    });

    test('uses the field names the native widget reads', () {
      final json = encodeSlots([_slot(1)]);
      for (final field in [
        SlotField.address,
        SlotField.slotStartMs,
        SlotField.lightPath,
        SlotField.darkPath,
        SlotField.packTextSha256,
        SlotField.lightBytes,
        SlotField.darkBytes,
        SlotField.renderMs,
      ]) {
        expect(json, contains('"$field":'));
      }
    });

    test('refuses what is not a list of whole slots', () {
      for (final bad in [
        '',
        'nope',
        '{}',
        '[1]',
        '[{"address":"hafs:1:1"}]',
        encodeSlots([
          _slot(1),
        ]).replaceFirst('"slotStartMs":1', '"slotStartMs":"1"'),
      ]) {
        expect(decodeSlots(bad), isNull, reason: bad);
      }
    });
  });

  test('labels are keyed by address', () {
    expect(encodeLabels({QuranAddress('hafs', 2, 3): 'x'}), '{"hafs:2:3":"x"}');
  });

  group('link', () {
    final ayah = QuranAddress('hafs', 2, 255);

    test('round-trips through its text form', () {
      final link = widgetLink(ayah);
      expect(link.scheme, 'holyquranspike');
      expect(link.host, 'ayah');
      expect(link.queryParameters, {'address': 'hafs:2:255'});
      expect(addressFromWidgetLink(Uri.parse(link.toString())), ayah);
    });

    test('reads the form the native widget builds', () {
      expect(
        addressFromWidgetLink(
          Uri.parse('holyquranspike://ayah?address=hafs%3A2%3A255'),
        ),
        ayah,
      );
    });

    test('refuses a word address', () {
      expect(
        () => widgetLink(QuranAddress('hafs', 2, 255, 1)),
        throwsArgumentError,
      );
    });

    test('gives null for foreign, word or garbage links', () {
      for (final link in <Uri?>[
        null,
        Uri(),
        Uri.parse('https://ayah?address=hafs:2:255'),
        Uri.parse('holyquranspike://surah?address=hafs:2:255'),
        Uri.parse('holyquranspike://ayah/x?address=hafs:2:255'),
        Uri.parse('holyquranspike://ayah?address=hafs:2:255#x'),
        Uri.parse('holyquranspike://ayah:80?address=hafs:2:255'),
        Uri.parse('holyquranspike://u@ayah?address=hafs:2:255'),
        Uri.parse('holyquranspike://ayah'),
        Uri.parse('holyquranspike://ayah?address=hafs:2:255:1'),
        Uri.parse('holyquranspike://ayah?address=hafs:0:1'),
        Uri.parse('holyquranspike://ayah?address=2:255'),
        Uri.parse('holyquranspike://ayah?address=hafs:2:255&address=hafs:1:1'),
        Uri.parse('holyquranspike://ayah?address=hafs:2:255&x=1'),
        Uri.parse('holyquranspike://ayah?address=%ZZ'),
      ]) {
        expect(addressFromWidgetLink(link), isNull, reason: '$link');
      }
    });
  });
}
