import 'package:flutter/foundation.dart';

import 'package:holyquran/config/dependencies.dart';
import 'package:holyquran/config/providers/user_database_providers.dart';
import 'package:holyquran/data/repositories/reading_position_repository.dart';
import 'package:holyquran/data/services/daos/reading_position_dao.dart';
import 'package:holyquran/utils/result.dart';

/// Provides the [ReadingPositionRepository] over the user database
/// (`RD-12`, D-106), read before the first frame. Reading the Quran needs no
/// user data, so a position that cannot be read provides nothing and the
/// reader opens at the start.
///
/// When the settings could not be read (D-133), the user's file is suspect:
/// the position is kept in an in-memory database instead, so nothing is ever
/// written to it.
Future<void> readingProviders(Dependencies dependencies) async {
  switch (await LocalReadingPositionRepository.load(
    ReadingPositionDao(userDataDatabase(dependencies)),
  )) {
    case Ok(:final value):
      dependencies.provideListenable<ReadingPositionRepository>(value);
    case Failure(:final error):
      debugPrint('Reading position unreadable, starting without it: $error');
  }
}
