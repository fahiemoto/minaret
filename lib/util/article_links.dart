import '../config.dart';

/// Alleen de eigen website mag een artikelroute in de app openen.
String? internalArticleSlug(Uri uri) {
  final siteHost = Uri.parse(AppConfig.websiteUrl).host;
  final hosts = {siteHost, siteHost.replaceFirst(RegExp(r'^www\.'), '')};
  if (!const {'http', 'https'}.contains(uri.scheme) ||
      !hosts.contains(uri.host)) {
    return null;
  }
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  return segments.length == 1 ? segments.single : null;
}
