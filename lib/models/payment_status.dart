/// Represents the lifecycle payment status of a customer order.
enum OrderPaymentStatus {
  pending,
  paid,
  failed,
  expired;

  String get label {
    switch (this) {
      case OrderPaymentStatus.pending:
        return 'Pending Payment';
      case OrderPaymentStatus.paid:
        return 'Paid';
      case OrderPaymentStatus.failed:
        return 'Payment Failed';
      case OrderPaymentStatus.expired:
        return 'Expired (Unpaid)';
    }
  }

  static OrderPaymentStatus fromString(String? status) {
    if (status == null) return OrderPaymentStatus.pending;
    switch (status.toLowerCase()) {
      case 'paid':
        return OrderPaymentStatus.paid;
      case 'failed':
        return OrderPaymentStatus.failed;
      case 'expired':
        return OrderPaymentStatus.expired;
      case 'pending':
      default:
        return OrderPaymentStatus.pending;
    }
  }

  String toDbValue() => name.toUpperCase();
}
