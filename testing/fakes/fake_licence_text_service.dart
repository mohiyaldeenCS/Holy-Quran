import 'package:holyquran/data/services/licence_text_service.dart';
import 'package:holyquran/utils/result.dart';

/// A [LicenceTextService] that answers [texts], or fails when [fails] is set.
final class FakeLicenceTextService implements LicenceTextService {
  FakeLicenceTextService([this.texts = const []]);

  final List<String> texts;
  bool fails = false;

  @override
  Future<Result<List<String>>> fontLicences() async =>
      fails ? Failure(Exception('synthetic')) : Ok(texts);
}
