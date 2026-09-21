import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../services/admin_product_service.dart';
import '../widgets/dashboard_shared.dart';

class SettingsSection extends StatelessWidget {
  final AdminProductService productService;
  final String initialStoreName;
  final int initialRowsPerPage;
  final bool initialShowCostColumn;
  final bool initialConfirmBeforeArchive;
  final ValueChanged<String> onStoreNameChanged;
  final ValueChanged<int> onRowsPerPageChanged;
  final ValueChanged<bool> onShowCostColumnChanged;
  final ValueChanged<bool> onConfirmBeforeArchiveChanged;

  const SettingsSection({
    super.key,
    required this.productService,
    required this.initialStoreName,
    required this.initialRowsPerPage,
    required this.initialShowCostColumn,
    required this.initialConfirmBeforeArchive,
    required this.onStoreNameChanged,
    required this.onRowsPerPageChanged,
    required this.onShowCostColumnChanged,
    required this.onConfirmBeforeArchiveChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Wait for service to initialize
    if (!productService.isInitialized) {
      return Center(
        child: CircularProgressIndicator(
          color: AppColors.primaryOrange,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        card(
          title: 'Store Settings',
          subtitle: 'Manage how the admin console looks and behaves.',
          child: Column(
            children: [
              _settingRow(
                'Store Name',
                'Displayed on receipts and the sidebar.',
                TextField(
                  onChanged: onStoreNameChanged,
                  decoration: InputDecoration(
                    hintText: initialStoreName,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const Divider(height: 32),
              _settingRow(
                'Rows per page',
                'Default number of rows in tables.',
                DropdownButton<int>(
                  value: initialRowsPerPage,
                  items: [5, 8, 10, 20, 50].map((v) => DropdownMenuItem(value: v, child: Text('$v rows'))).toList(),
                  onChanged: (v) { if (v != null) onRowsPerPageChanged(v); },
                ),
              ),
              const Divider(height: 32),
              _settingRow(
                'Show Cost Column',
                'Show product cost prices in the Products table.',
                Switch(
                  value: initialShowCostColumn,
                  onChanged: onShowCostColumnChanged,
                ),
              ),
              const Divider(height: 32),
              _settingRow(
                'Confirm before Archive',
                'Show a confirmation dialog before archiving records.',
                Switch(
                  value: initialConfirmBeforeArchive,
                  onChanged: onConfirmBeforeArchiveChanged,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _settingRow(String title, String subtitle, Widget control) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
        const SizedBox(width: 20),
        SizedBox(width: 200, child: Align(alignment: Alignment.centerRight, child: control)),
      ],
    );
  }
}