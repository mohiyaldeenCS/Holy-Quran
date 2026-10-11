import 'dart:convert';

import 'package:holyquran/domain/models/quran_address.dart';

// What the Flutter side and the native ayah widget share (S4 approach A,
// D-094): the storage keys, the JSON of the slots and labels, the rule that
// picks a slot, and the link a tap opens. AyahWidgetProvider.kt mirrors every
// name here; widget_native_source_test.dart checks that it does.

/// The two faces of the widget: 4x2 and 2x2 (D-093, reading 1).
enum WidgetFaceSize { medium, small }

/// One day of one face: the ayah, when its day starts, and its two images,
/// each with the length and the lowercase hex SHA-256 of its PNG bytes as
/// saved. Nothing in it is Quran text.
typedef WidgetSlotInfo = ({
  String address,
  int slotStartMs,
  String lightPath,
  String darkPath,
  String packTextSha256,
  int lightBytes,
  int darkBytes,
  String lightSha256,
  String darkSha256,
  int renderMs,
});

/// The key of the JSON list of a face's slots.
String slotsKey(WidgetFaceSize size) => 'ayah_widget_slots_${size.name}';

/// The key of the JSON object from address to accessibility label (AX-01).
const String labelsKey = 'ayah_widget_labels';

/// The key, and the file name without `.png`, of one image of one slot.
String imageKey(WidgetFaceSize size, int index, {required bool night}) {
  if (index < 0) throw ArgumentError.value(index, 'index', 'is negative');
  return 'ayah_widget_${size.name}_${index}_${night ? 'night' : 'paper'}';
}

/// The slot fields as stored, in the order of [WidgetSlotInfo].
abstract final class SlotField {
  static const address = 'address';
  static const slotStartMs = 'slotStartMs';
  static const lightPath = 'lightPath';
  static const darkPath = 'darkPath';
  static const packTextSha256 = 'packTextSha256';
  static const lightBytes = 'lightBytes';
  static const darkBytes = 'darkBytes';
  static const lightSha256 = 'lightSha256';
  static const darkSha256 = 'darkSha256';
  static const renderMs = 'renderMs';
}

/// The local midnight of [now]'s day and of each of the [days] - 1 days after
/// it. Built from the calendar date, so a day across a DST change keeps its
/// midnight.
List<DateTime> slotStarts(DateTime now, int days) {
  if (days < 1) throw ArgumentError.value(days, 'days', 'must be at least 1');
  final local = now.toLocal();
  return [
    for (var day = 0; day < days; day++)
      DateTime(local.year, local.month, local.day + day),
  ];
}

/// The slot to show at [nowMs]: the last whose day has started, else the
/// first; null when there are none.
WidgetSlotInfo? slotAt(List<WidgetSlotInfo> slots, int nowMs) {
  WidgetSlotInfo? shown;
  for (final slot in slots) {
    if (slot.slotStartMs <= nowMs) shown = slot;
  }
  return shown ?? (slots.isEmpty ? null : slots.first);
}

String encodeSlots(List<WidgetSlotInfo> slots) => jsonEncode([
  for (final slot in slots)
    {
      SlotField.address: slot.address,
      SlotField.slotStartMs: slot.slotStartMs,
      SlotField.lightPath: slot.lightPath,
      SlotField.darkPath: slot.darkPath,
      SlotField.packTextSha256: slot.packTextSha256,
      SlotField.lightBytes: slot.lightBytes,
      SlotField.darkBytes: slot.darkBytes,
      SlotField.lightSha256: slot.lightSha256,
      SlotField.darkSha256: slot.darkSha256,
      SlotField.renderMs: slot.renderMs,
    },
]);

/// The slots in [json], or null when it is not a list of whole slots.
List<WidgetSlotInfo>? decodeSlots(String json) {
  final Object? decoded;
  try {
    decoded = jsonDecode(json);
  } on FormatException {
    return null;
  }
  if (decoded is! List<Object?>) return null;
  final slots = <WidgetSlotInfo>[];
  for (final entry in decoded) {
    if (entry case {
      SlotField.address: final String address,
      SlotField.slotStartMs: final int slotStartMs,
      SlotField.lightPath: final String lightPath,
      SlotField.darkPath: final String darkPath,
      SlotField.packTextSha256: final String packTextSha256,
      SlotField.lightBytes: final int lightBytes,
      SlotField.darkBytes: final int darkBytes,
      SlotField.lightSha256: final String lightSha256,
      SlotField.darkSha256: final String darkSha256,
      SlotField.renderMs: final int renderMs,
    }) {
      slots.add((
        address: address,
        slotStartMs: slotStartMs,
        lightPath: lightPath,
        darkPath: darkPath,
        packTextSha256: packTextSha256,
        lightBytes: lightBytes,
        darkBytes: darkBytes,
        lightSha256: lightSha256,
        darkSha256: darkSha256,
        renderMs: renderMs,
      ));
    } else {
      return null;
    }
  }
  return slots;
}

String encodeLabels(Map<QuranAddress, String> labels) => jsonEncode({
  for (final MapEntry(:key, :value) in labels.entries) key.toString(): value,
});

/// The scheme, host and parameter of the link a tap on the widget opens.
abstract final class WidgetLink {
  static const scheme = 'holyquranspike';
  static const host = 'ayah';
  static const address = 'address';
}

/// The link that opens [ayah]; a word address is refused.
Uri widgetLink(QuranAddress ayah) {
  if (ayah.isWord) {
    throw ArgumentError.value(ayah, 'ayah', 'is a word address');
  }
  return Uri(
    scheme: WidgetLink.scheme,
    host: WidgetLink.host,
    queryParameters: {WidgetLink.address: ayah.toString()},
  );
}

/// The ayah [link] opens, or null for any link [widgetLink] does not make.
QuranAddress? addressFromWidgetLink(Uri? link) {
  if (link == null ||
      link.scheme != WidgetLink.scheme ||
      link.host != WidgetLink.host ||
      link.path.isNotEmpty ||
      link.hasFragment ||
      link.userInfo.isNotEmpty ||
      link.hasPort) {
    return null;
  }
  final Map<String, List<String>> parameters;
  try {
    parameters = link.queryParametersAll;
  } on FormatException {
    return null;
  }
  if (parameters.length != 1) return null;
  final values = parameters[WidgetLink.address];
  if (values == null || values.length != 1) return null;
  final address = QuranAddress.tryParse(values.single);
  return address == null || address.isWord ? null : address;
}
