import 'package:holyquran/data/services/mail_service.dart';
import 'package:holyquran/utils/result.dart';

/// A [MailService] that opens nothing, for view and view-model tests. Every
/// draft asked for is logged in [composed]; it fails while [fails] is set.
final class FakeMailService implements MailService {
  bool fails = false;
  final List<MailDraft> composed = [];

  @override
  Future<Result<void>> compose(MailDraft draft) async {
    composed.add(draft);
    return fails ? Failure(MailNotOpened(draft.to)) : const Ok(null);
  }
}
