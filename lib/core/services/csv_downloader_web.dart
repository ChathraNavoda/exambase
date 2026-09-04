import 'dart:html' as html;

Future<void> downloadCsvPlatform(String csvContent, String filename) async {
  final bytes = html.Blob([csvContent], 'text/csv');
  final url = html.Url.createObjectUrlFromBlob(bytes);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}
