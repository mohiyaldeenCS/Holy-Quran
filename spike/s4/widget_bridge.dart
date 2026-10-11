import 'dart:io';
import 'dart:typed_data';

import 'package:holyquran/domain/models/quran_address.dart';
import 'package:home_widget/home_widget.dart';
import 'package:path_provider/path_provider.dart';

import 'widget_slots.dart';

/// What the S4 publisher needs of the home-screen widget plugin. Only
/// [HomeWidgetBridge] touches the plugin and the file system.
abstract interface class WidgetBridge {
  /// Writes [png] as `<key>.png` and returns its absolute path.
  Future<String> savePng(String key, Uint8List png);

  Future<void> saveString(String key, String value);

  /// Asks the system to redraw the widget at each of [times].
  Future<void> scheduleUpdates(List<DateTime> times);

  /// Redraws every placed widget now.
  Future<void> update();

  /// Asks the launcher to place the widget; false where it cannot.
  Future<bool> requestPin();

  /// The ayah whose widget launched the app, if it was launched by one.
  Future<QuranAddress?> launchAddress();

  /// The ayah of each tap on the widget while the app runs; null for a tap
  /// whose link names none.
  Stream<QuranAddress?> get taps;
}

/// A plugin call that answered something other than success.
final class WidgetBridgeException implements Exception {
  const WidgetBridgeException(this.call, this.answer);

  final String call;
  final Object? answer;

  @override
  String toString() => 'WidgetBridgeException: $call answered $answer';
}

/// The fully qualified name of AyahWidgetProvider.kt's class.
const String ayahWidgetProvider = 'com.example.holyquran.AyahWidgetProvider';

/// [WidgetBridge] over `home_widget` 0.10.0 (D-094), its images in
/// [imageDirectory].
final class HomeWidgetBridge implements WidgetBridge {
  HomeWidgetBridge(this.imageDirectory);

  /// A bridge whose images live in the app's support directory.
  static Future<HomeWidgetBridge> open() async {
    final support = await getApplicationSupportDirectory();
    return HomeWidgetBridge(Directory('${support.path}/ayah_widget'));
  }

  final Directory imageDirectory;

  static final _fileNameSafe = RegExp(r'^[a-z0-9_]+$');

  /// Written beside and renamed over the old image, so the widget never
  /// decodes a half-written file.
  @override
  Future<String> savePng(String key, Uint8List png) async {
    if (!_fileNameSafe.hasMatch(key)) {
      throw ArgumentError.value(key, 'key', 'is not a safe file name');
    }
    await imageDirectory.create(recursive: true);
    final path = '${imageDirectory.path}/$key.png';
    final partial = File('$path.partial');
    await partial.writeAsBytes(png, flush: true);
    await partial.rename(path);
    return path;
  }

  @override
  Future<void> saveString(String key, String value) async {
    final answer = await HomeWidget.saveWidgetData<String>(key, value);
    if (answer != true) throw WidgetBridgeException('saveWidgetData', answer);
  }

  @override
  Future<void> scheduleUpdates(List<DateTime> times) async {
    final answer = await HomeWidget.scheduleWidgetUpdates(
      times,
      qualifiedAndroidName: ayahWidgetProvider,
    );
    if (answer != true) {
      throw WidgetBridgeException('scheduleWidgetUpdates', answer);
    }
  }

  @override
  Future<void> update() async {
    final answer = await HomeWidget.updateWidget(
      qualifiedAndroidName: ayahWidgetProvider,
    );
    if (answer != true) throw WidgetBridgeException('updateWidget', answer);
  }

  @override
  Future<bool> requestPin() async {
    final supported = await HomeWidget.isRequestPinWidgetSupported() ?? false;
    if (supported) {
      await HomeWidget.requestPinWidget(
        qualifiedAndroidName: ayahWidgetProvider,
      );
    }
    return supported;
  }

  @override
  Future<QuranAddress?> launchAddress() async =>
      addressFromWidgetLink(await HomeWidget.initiallyLaunchedFromHomeWidget());

  @override
  Stream<QuranAddress?> get taps =>
      HomeWidget.widgetClicked.map(addressFromWidgetLink);
}
