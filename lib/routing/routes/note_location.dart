import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/routing/routes.dart';

/// The query parameter of the note sheet that names the note to open on.
const noteParameter = 'note';

/// The note sheet of [address], opened on the note [noteId] when it is given.
/// `Routes.noteSheet` is the same sheet for a new note.
String noteSheetLocation(QuranAddress address, {String? noteId}) => Uri(
  path: Routes.noteSheet(address),
  queryParameters: noteId == null ? null : {noteParameter: noteId},
).toString();
