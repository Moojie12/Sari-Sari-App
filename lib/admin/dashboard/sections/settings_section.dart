import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../services/admin_product_service.dart';

class SettingsSection extends StatelessWidget {
  final AdminProductService? productService;
  final String? initialStoreName;
  final int? initialRowsPerPage;
  final bool? initialShowCostColumn;
  final bool? initialConfirmBeforeArchive;
  final ValueChanged<String>? onStoreNameChanged;
  final ValueChanged<int>? onRowsPerPageChanged;
  final ValueChanged<bool>? onShowCostColumnChanged;
  final ValueChanged<bool>? onConfirmBeforeArchiveChanged;

  const SettingsSection({
    super.key,
    this.productService,
    this.initialStoreName,
    this.initialRowsPerPage,
    this.initialShowCostColumn,
    this.initialConfirmBeforeArchive,
    this.onStoreNameChanged,
    this.onRowsPerPageChanged,
    this.onShowCostColumnChanged,
    this.onConfirmBeforeArchiveChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        margin: const EdgeInsets.only(top: 40),
        constraints: const BoxConstraints(maxWidth: 520),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryOrange.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.settings_suggest_rounded,
                size: 40,
                color: AppColors.primaryOrange,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Settings Dashboard',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.darkText,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This section is currently cleared and ready for pending settings.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
