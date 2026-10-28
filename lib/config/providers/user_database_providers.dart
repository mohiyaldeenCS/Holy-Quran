import 'package:holyquran/config/dependencies.dart';
import 'package:holyquran/data/services/user_database.dart';

/// Opens the user's database in application support and provides it for the
/// areas after this one. A database that cannot open stops the start.
Future<void> userDatabaseProviders(Dependencies dependencies) async =>
    dependencies.provide<UserDatabase>(await UserDatabase.open());
