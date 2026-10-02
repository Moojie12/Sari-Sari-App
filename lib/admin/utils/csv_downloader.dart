import 'csv_downloader_stub.dart'
    if (dart.library.html) 'csv_downloader_web.dart'
    if (dart.library.io) 'csv_downloader_io.dart' as impl;

/// Exports or downloads CSV content to a file cross-platform.
/// Returns the saved file path on IO, or 'browser_downloaded' on Web, or null on error.
Future<String?> exportCsvFile(String csvContent, String filename) {
  return impl.downloadCsvFile(csvContent, filename);
}
