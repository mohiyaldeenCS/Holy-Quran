import 'package:holyquran/config/dependencies.dart';
import 'package:holyquran/data/services/link_service.dart';

/// Provides the service that opens a source's link in the browser. It does
/// not touch the plugin until a link is opened.
Future<void> linksProviders(Dependencies dependencies) async {
  dependencies.provide<LinkService>(const SystemLinkService());
}
