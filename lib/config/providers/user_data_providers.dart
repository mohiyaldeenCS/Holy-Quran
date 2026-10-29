import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:holyquran/config/dependencies.dart';
import 'package:holyquran/config/providers/user_database_providers.dart';
import 'package:holyquran/data/repositories/app_settings_repository.dart';
import 'package:holyquran/data/repositories/bookmark_repository.dart';
import 'package:holyquran/data/repositories/category_repository.dart';
import 'package:holyquran/data/repositories/integrity_log_repository.dart';
import 'package:holyquran/data/repositories/keep_awake_repository.dart';
import 'package:holyquran/data/repositories/listening_position_repository.dart';
import 'package:holyquran/data/repositories/note_repository.dart';
import 'package:holyquran/data/repositories/pack_integrity_repository.dart';
import 'package:holyquran/data/repositories/search_history_repository.dart';
import 'package:holyquran/data/repositories/tag_repository.dart';
import 'package:holyquran/data/services/daos/bookmark_dao.dart';
import 'package:holyquran/data/services/daos/category_dao.dart';
import 'package:holyquran/data/services/daos/integrity_log_dao.dart';
import 'package:holyquran/data/services/daos/listening_position_dao.dart';
import 'package:holyquran/data/services/daos/note_dao.dart';
import 'package:holyquran/data/services/daos/search_history_dao.dart';
import 'package:holyquran/data/services/daos/tag_dao.dart';
import 'package:holyquran/data/services/user_database.dart';
import 'package:holyquran/data/services/wakelock_service.dart';
import 'package:holyquran/domain/models/pack_integrity.dart';
import 'package:holyquran/utils/result.dart';

/// Provides the user's data over the user database, with the keep-awake
/// state following the settings and the integrity log storing the events of
/// the [PackIntegrityRepository] when the Quran area provided one.
///
/// Reading the Quran needs no user data. When a repository cannot load, the
/// user's file is suspect, so the data is kept in a database in memory
/// instead ([useDatabaseInMemory], D-133), and the start goes on.
Future<void> userDataProviders(Dependencies dependencies) async {
  final database = dependencies.read<UserDatabase>();
  Future<void> provide(UserDatabase over) => provideUserData(
    dependencies,
    database: over,
    settings: dependencies.read<AppSettingsRepository>(),
    wakelock: const WakelockService(),
    integrityEvents: dependencies.tryRead<PackIntegrityRepository>()?.events,
  );
  try {
    await provide(database);
  } on Exception catch (error, stack) {
    debugPrint('User data unreadable, keeping it in memory: $error');
    debugPrintStack(stackTrace: stack);
    final memory = useDatabaseInMemory(dependencies);
    if (identical(memory, database)) rethrow;
    await provide(memory);
  }
}

/// Provides the repositories of the user's own data over [database]: the
/// keep-awake state follows [settings], and the integrity log stores
/// [integrityEvents]. Throws the error of a repository that cannot load,
/// before it has provided or listened to anything.
Future<void> provideUserData(
  Dependencies dependencies, {
  required UserDatabase database,
  required AppSettingsRepository settings,
  required WakelockService wakelock,
  Stream<PackIntegrityEvent>? integrityEvents,
}) async {
  final listening = switch (await LocalListeningPositionRepository.load(
    ListeningPositionDao(database),
  )) {
    Ok(:final value) => value,
    Failure(:final error) => throw error,
  };
  final keepAwake = LocalKeepAwakeRepository(wakelock);
  _reportKeepAwake(await keepAwake.setSettingOn(settings.keepScreenAwake));
  settings.addListener(
    () => unawaited(
      keepAwake.setSettingOn(settings.keepScreenAwake).then(_reportKeepAwake),
    ),
  );

  dependencies
    ..provideListenable<BookmarkRepository>(
      LocalBookmarkRepository(BookmarkDao(database)),
    )
    ..provideListenable<NoteRepository>(LocalNoteRepository(NoteDao(database)))
    ..provideListenable<TagRepository>(LocalTagRepository(TagDao(database)))
    ..provide<CategoryRepository>(
      LocalCategoryRepository(CategoryDao(database)),
    )
    ..provideListenable<ListeningPositionRepository>(listening)
    ..provideListenable<SearchHistoryRepository>(
      LocalSearchHistoryRepository(SearchHistoryDao(database)),
    )
    ..provideListenable<IntegrityLogRepository>(
      LocalIntegrityLogRepository(
        IntegrityLogDao(database),
        integrityEvents ?? const Stream.empty(),
      ),
    )
    ..provideListenable<KeepAwakeRepository>(keepAwake);
}

/// A wakelock that cannot follow the setting is no reason to stop; it is
/// reported as main.dart reports a failed start.
void _reportKeepAwake(Result<void> result) {
  if (result case Failure(:final error)) {
    FlutterError.reportError(
      FlutterErrorDetails(exception: error, library: 'keep awake'),
    );
  }
}
