import 'dart:math';
import '../../users/employee_db/employee_inventory_controller.dart';

/// Utility class to auto-generate unique barcodes for sari-sari store products
/// that do not have existing physical barcodes on their packaging.
class BarcodeGenerator {
  BarcodeGenerator._();

  /// Generates a unique system barcode (e.g. `SS-849201948`).
  /// Checks against active products in [EmployeeInventoryController] to ensure
  /// no barcode collisions occur in the database.
  static String generateUniqueBarcode({
    String prefix = 'SS',
    EmployeeInventoryController? inventoryController,
  }) {
    final controller = inventoryController ?? EmployeeInventoryController.instance;
    final random = Random();

    String candidate;
    int attempts = 0;

    do {
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      // Take last 6 digits of timestamp + 3 random digits
      final timePart = timestamp.length >= 6
          ? timestamp.substring(timestamp.length - 6)
          : timestamp;
      final randPart = (random.nextInt(900) + 100).toString();
      candidate = '$prefix-$timePart$randPart';
      attempts++;
    } while (controller.isBarcodeTaken(candidate) && attempts < 100);

    return candidate;
  }
}
