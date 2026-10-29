import 'package:flutter/foundation.dart';

import 'package:holyquran/config/providers/address_providers.dart';
import 'package:holyquran/config/providers/audio_providers.dart';
import 'package:holyquran/config/providers/catalogue_providers.dart';
import 'package:holyquran/config/providers/links_providers.dart';
import 'package:holyquran/config/providers/pack_install_providers.dart';
import 'package:holyquran/config/providers/quran_providers.dart';
import 'package:holyquran/config/providers/reading_providers.dart';
import 'package:holyquran/config/providers/search_providers.dart';
import 'package:holyquran/config/providers/settings_providers.dart';
import 'package:holyquran/config/providers/share_providers.dart';
import 'package:holyquran/config/providers/tafsir_providers.dart';
import 'package:holyquran/config/providers/user_data_providers.dart';
import 'package:holyquran/config/providers/user_database_providers.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

/// Sets up one area's objects and provides them. It may read what earlier
/// areas provided.
typedef AreaSetup = Future<void> Function(Dependencies dependencies);

/// The areas in the order they are set up (D-103).
const List<AreaSetup> appAreas = [
  userDatabaseProviders,
  settingsProviders,
  readingProviders,
  quranProviders,
  packInstallProviders,
  catalogueProviders,
  userDataProviders,
  audioProviders,
  tafsirProviders,
  searchProviders,
  shareProviders,
  addressProviders,
  linksProviders,
];

/// The app's providers, built by setting up [areas] one after another.
Future<List<SingleChildWidget>> buildDependencies({
  List<AreaSetup> areas = appAreas,
}) async {
  final dependencies = Dependencies._();
  for (final area in areas) {
    await area(dependencies);
  }
  return dependencies._providers;
}

/// What the areas set up so far have provided.
final class Dependencies {
  Dependencies._();

  final _values = <Type, Object>{};
  final _providers = <SingleChildWidget>[];
  final _slots = <Type, int>{};

  /// The [T] an earlier area provided. Throws a [StateError] if none did.
  T read<T extends Object>() =>
      tryRead<T>() ??
      (throw StateError('$T is not provided by an earlier area'));

  /// The [T] an earlier area provided, or null for what that area leaves out,
  /// such as everything that needs a verified base pack.
  T? tryRead<T extends Object>() => _values[T] as T?;

  /// Provides [value] as [T]. A [Listenable] goes through [provideListenable].
  void provide<T extends Object>(T value) {
    _keep<T>(value);
    _slots[T] = _providers.length;
    _providers.add(Provider<T>.value(value: value));
  }

  /// Gives [value] in place of the [T] an earlier area provided with
  /// [provide], for readers of both the areas after it and the widget tree.
  /// Throws a [StateError] if no earlier area did.
  void replace<T extends Object>(T value) {
    final slot = _slots[T];
    if (slot == null) {
      throw StateError('$T was not provided by an earlier area');
    }
    _values[T] = value;
    _providers[slot] = Provider<T>.value(value: value);
  }

  /// Provides [value] as [T], rebuilding its readers when it notifies.
  void provideListenable<T extends Listenable>(T value) {
    _keep<T>(value);
    _providers.add(ListenableProvider<T>.value(value: value));
  }

  void _keep<T extends Object>(T value) {
    if (_values.containsKey(T)) {
      throw StateError('$T is already provided');
    }
    _values[T] = value;
  }
}
