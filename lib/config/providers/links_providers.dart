import 'package:holyquran/config/dependencies.dart';
import 'package:holyquran/data/services/link_service.dart';
import 'package:holyquran/data/services/mail_service.dart';

/// Provides the services that open a source's link in the browser and an
/// error report in the mail app. Neither touches the plugin until it opens
/// something.
Future<void> linksProviders(Dependencies dependencies) async {
  dependencies
    ..provide<LinkService>(const SystemLinkService())
    ..provide<MailService>(const SystemMailService());
}
