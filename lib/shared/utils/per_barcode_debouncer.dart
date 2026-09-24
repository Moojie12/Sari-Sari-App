/// Utility class for per-barcode camera debounce protection.
/// Prevents accidental duplicate frames on the same barcode within a short window
/// (e.g. 400ms) without delaying or blocking rapid sequential scans of different items.
class PerBarcodeDebouncer {
  PerBarcodeDebouncer({this.debounceWindow = const Duration(milliseconds: 400)});

  final Duration debounceWindow;
  String? _lastBarcode;
  DateTime? _lastTimestamp;

  /// Returns `true` if [barcode] is a duplicate scan received within the debounce window.
  /// Returns `false` if [barcode] is a new item or if sufficient time has elapsed.
  bool shouldIgnore(String barcode) {
    final now = DateTime.now();

    if (_lastBarcode == barcode && _lastTimestamp != null) {
      final elapsed = now.difference(_lastTimestamp!);
      if (elapsed < debounceWindow) {
        return true; // Ignore duplicate scan within window
      }
    }

    _lastBarcode = barcode;
    _lastTimestamp = now;
    return false; // Accept scan
  }

  /// Resets the debouncer state.
  void reset() {
    _lastBarcode = null;
    _lastTimestamp = null;
  }
}
