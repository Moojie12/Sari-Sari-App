import 'dart:io';
import 'package:flutter/foundation.dart';

Future<String?> downloadCsvFile(String csvContent, String filename) async {
  try {
    String? dirPath;
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
      if (home != null) {
        final downloadsDir = Directory('$home${Platform.pathSeparator}Downloads');
        if (downloadsDir.existsSync()) {
          dirPath = downloadsDir.path;
        } else {
          dirPath = home;
        }
      }
    }
    dirPath ??= Directory.current.path;
    final filePath = '$dirPath${Platform.pathSeparator}$filename';
    final file = File(filePath);
    await file.writeAsString(csvContent);
    debugPrint('CSV file saved successfully to: $filePath');
    return filePath;
  } catch (e) {
    debugPrint('Error saving CSV file to local disk: $e');
    return null;
  }
}
