import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';

Future<void> downloadCsvPlatform(String csvContent, String filename) async {
  final bytes = Uint8List.fromList(csvContent.codeUnits);
  final file = XFile.fromData(bytes, name: filename, mimeType: 'text/csv');
  await Share.shareXFiles([file], text: filename);
}
