import '../models/admin_models.dart';

class SalesCsvGenerator {
  /// Generates CSV formatted string from a list of [AdminSale] records.
  /// Includes UTF-8 BOM so Microsoft Excel correctly displays currency and characters.
  static String generateSalesCsv({
    required List<AdminSale> sales,
    required String periodName,
    String storeName = 'Tindahan ni Eca',
  }) {
    final buffer = StringBuffer();

    // UTF-8 BOM
    buffer.write('\uFEFF');

    // Header metadata comments
    buffer.writeln('# Store: $storeName');
    buffer.writeln('# Report: Sales Records ($periodName)');
    buffer.writeln('# Export Date: ${formatDateTime(DateTime.now())}');
    buffer.writeln('# Total Transactions: ${sales.length}');
    final totalRevenue = sales
        .where((s) => s.isCompleted)
        .fold<double>(0, (sum, s) => sum + s.total);
    buffer.writeln('# Total Completed Revenue (PHP): ${totalRevenue.toStringAsFixed(2)}');
    buffer.writeln('');

    // Column headers
    final headers = [
      'Receipt #',
      'Date & Time',
      'Transactions',
      'Customer',
      'Handled By',
      'Items Count',
      'Subtotal (PHP)',
      'Discount (PHP)',
      'Total (PHP)',
      'Payment Method',
      'Status',
      'Items Details',
    ];
    buffer.writeln(_csvRow(headers));

    // Data rows
    for (final sale in sales) {
      final itemsSummary = sale.items.isNotEmpty
          ? sale.items
              .map((i) => '${i.quantity.toStringAsFixed(i.quantity % 1 == 0 ? 0 : 2)}x ${i.productName}')
              .join('; ')
          : 'N/A';

      final row = [
        sale.receiptNumber,
        formatDateTime(sale.timestamp),
        sale.transactionType.label,
        sale.customerName,
        sale.handledByDisplay,
        sale.items.length.toString(),
        sale.subtotal.toStringAsFixed(2),
        sale.discount.toStringAsFixed(2),
        sale.total.toStringAsFixed(2),
        sale.paymentMethod.label,
        sale.status.label,
        itemsSummary,
      ];
      buffer.writeln(_csvRow(row));
    }

    return buffer.toString();
  }

  static String _csvRow(List<String> values) {
    return values.map(_escapeCsvField).join(',');
  }

  static String _escapeCsvField(String field) {
    // If the field contains comma, quote, or newline, wrap in quotes and escape internal quotes
    if (field.contains(',') ||
        field.contains('"') ||
        field.contains('\n') ||
        field.contains('\r')) {
      final escaped = field.replaceAll('"', '""');
      return '"$escaped"';
    }
    return field;
  }
}
