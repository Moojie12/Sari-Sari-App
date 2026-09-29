import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';

// ==================== TABLE PRIMITIVES ====================

Widget tableShell({
  required List<Widget> header,
  required List<List<Widget>> rows,
  required Map<int, TableColumnWidth> columnWidths,
  required Widget footer,
  double minWidth = 820,
}) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.92),
              Colors.white.withValues(alpha: 0.78),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.9),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.darkText.withValues(alpha: 0.06),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.6),
              blurRadius: 0,
              spreadRadius: 1,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final tableWidth = constraints.maxWidth < minWidth
                    ? minWidth
                    : constraints.maxWidth;
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: tableWidth,
                    child: Table(
                      columnWidths: columnWidths,
                      defaultVerticalAlignment:
                      TableCellVerticalAlignment.middle,
                      children: [
                        TableRow(
                          decoration: BoxDecoration(
                            color: AppColors.primaryOrange.withValues(alpha: 0.06),
                            border: const Border(
                              bottom: BorderSide(
                                  color: AppColors.borderColor, width: 1),
                            ),
                          ),
                          children: header,
                        ),
                        for (var i = 0; i < rows.length; i++)
                          TableRow(
                            decoration: BoxDecoration(
                              color: i % 2 == 0
                                  ? Colors.white.withValues(alpha: 0.5)
                                  : Colors.white.withValues(alpha: 0.8),
                              border: i == rows.length - 1
                                  ? null
                                  : Border(
                                bottom: BorderSide(
                                  color: AppColors.borderColor.withValues(alpha: 0.6),
                                  width: 0.6,
                                ),
                              ),
                            ),
                            children: rows[i],
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
            footer,
          ],
        ),
      ),
    ),
  );
}

Widget header(String label) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Text(
      label,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        color: AppColors.labelText,
        fontSize: 12.5,
      ),
    ),
  );
}

Widget sortableHeader(String label, String key, String currentKey,
    bool ascending, ValueChanged<String> onTap) {
  final isActive = currentKey == key;
  return InkWell(
    onTap: () => onTap(key),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isActive
                    ? AppColors.primaryOrange
                    : AppColors.labelText,
                fontSize: 12.5,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            isActive
                ? (ascending
                ? Icons.arrow_upward
                : Icons.arrow_downward)
                : Icons.unfold_more,
            size: 13,
            color: isActive
                ? AppColors.primaryOrange
                : AppColors.placeholderColor,
          ),
        ],
      ),
    ),
  );
}

Widget cell(Widget child,
    {EdgeInsets padding =
    const EdgeInsets.symmetric(horizontal: 16, vertical: 14)}) {
  return Padding(padding: padding, child: child);
}

Widget statusPill(String label, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    ),
  );
}

Widget iconAction(
    IconData icon, String tooltip, Color color, VoidCallback onPressed) {
  return IconButton(
    tooltip: tooltip,
    icon: Icon(icon, size: 19),
    color: color,
    visualDensity: VisualDensity.compact,
    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    padding: EdgeInsets.zero,
    onPressed: onPressed,
  );
}

// ==================== DIALOG PRIMITIVES ====================

double dialogWidth(BuildContext context, double desired) {
  final screenWidth = MediaQuery.of(context).size.width;
  final maxAllowed = screenWidth * 0.92;
  return desired > maxAllowed ? maxAllowed : desired;
}

Widget dialogShell(BuildContext context, {
  required double width,
  required Widget child,
  bool scrollable = false,
}) {
  final content = Container(
    width: dialogWidth(context, width),
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.86,
    ),
    padding: const EdgeInsets.all(28),
    child: scrollable ? SingleChildScrollView(child: child) : child,
  );
  return Dialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    clipBehavior: Clip.antiAlias,
    child: content,
  );
}

Widget dialogRow(String label, Widget control) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AppColors.secondaryText,
            ),
          ),
        ),
        Flexible(child: Align(alignment: Alignment.centerRight, child: control)),
      ],
    ),
  );
}

Widget dialogActions(
    BuildContext dialogContext, {
      required String confirmLabel,
      required VoidCallback onConfirm,
      Color? confirmColor,
      String cancelLabel = 'Cancel',
    }) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      TextButton(
        onPressed: () => Navigator.pop(dialogContext),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.secondaryText,
          padding:
          const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        ),
        child: Text(cancelLabel),
      ),
      const SizedBox(width: 10),
      ElevatedButton(
        onPressed: onConfirm,
        style: ElevatedButton.styleFrom(
          backgroundColor: confirmColor ?? AppColors.primaryOrange,
          elevation: 0,
          padding:
          const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
          confirmLabel,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
    ],
  );
}

Widget formError(String message) {
  return Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.red[800],
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget field(
    TextEditingController controller,
    String label, {
      String? hint,
      String? prefix,
      bool numeric = false,
      bool isPassword = false,
    }) {
  return TextField(
    controller: controller,
    obscureText: isPassword,
    keyboardType: numeric
        ? const TextInputType.numberWithOptions(decimal: true)
        : TextInputType.text,
    inputFormatters: numeric
        ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
        : null,
    style: const TextStyle(fontSize: 14, color: AppColors.darkText),
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      prefixText: prefix,
      isDense: true,
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    ),
  );
}

// ==================== OTHER SHARED UI ====================

Widget card({
  required String title,
  String? subtitle,
  Widget? trailing,
  required Widget child,
  EdgeInsets padding = const EdgeInsets.all(22),
}) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.92),
              Colors.white.withValues(alpha: 0.78),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.9),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.darkText.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkText,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[trailing],
              ],
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    ),
  );
}

Widget toolbar({required List<Widget> filters, required Widget action}) {
  return Wrap(
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 16,
    runSpacing: 12,
    children: [
      Wrap(spacing: 10, runSpacing: 10, children: filters),
      action,
    ],
  );
}

Widget searchFilter({
  required TextEditingController controller,
  required String hintText,
  required ValueChanged<String> onChanged,
  VoidCallback? onClear,
}) {
  return Container(
    width: 240,
    height: 40,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.2),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: TextField(
      controller: controller,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 13, color: AppColors.darkText, fontWeight: FontWeight.w500),
      textAlignVertical: TextAlignVertical.center,
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        hintText: hintText,
        hintStyle: const TextStyle(fontSize: 12.5, color: AppColors.placeholderColor),
        prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.secondaryText),
        prefixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 16, color: AppColors.secondaryText),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                  if (onClear != null) onClear();
                },
              )
            : null,
        border: InputBorder.none,
      ),
    ),
  );
}

Widget dropdownFilter({
  required String label,
  required String value,
  required List<String> options,
  required ValueChanged<String> onChanged,
}) {
  final safeValue = options.contains(value) ? value : options.first;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.2),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label:',
          style: const TextStyle(
            fontSize: 12.5,
            color: AppColors.secondaryText,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 6),
        DropdownButton<String>(
          value: safeValue,
          underline: const SizedBox(),
          isDense: true,
          borderRadius: BorderRadius.circular(12),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.darkText,
          ),
          items: options
              .map((option) => DropdownMenuItem(
            value: option,
            child: Text(option),
          ))
              .toList(),
          onChanged: (selected) {
            if (selected != null) onChanged(selected);
          },
        ),
      ],
    ),
  );
}

Widget primaryButton({
  required IconData icon,
  required String label,
  required VoidCallback onPressed,
}) {
  return ElevatedButton.icon(
    onPressed: onPressed,
    icon: Icon(icon, color: Colors.white, size: 18),
    label: Text(
      label,
      style: const TextStyle(
          color: Colors.white, fontWeight: FontWeight.w700),
    ),
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primaryOrange,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 17),
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

Widget emptyState({
  required IconData icon,
  required String title,
  required String message,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 56),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.92),
              Colors.white.withValues(alpha: 0.78),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.9),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.darkText.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.primaryOrange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 30, color: AppColors.primaryOrange),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: AppColors.darkText,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: AppColors.secondaryText,
                  height: 1.5,
                ),
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 22),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  actionLabel,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

Widget detailRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.secondaryText,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          flex: 6,
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.darkText,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
      ],
    ),
  );
}

// ==================== PAGINATION HELPER ====================

class Paged<T> {
  const Paged({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.start,
    required this.end,
    required this.total,
  });

  final List<T> items;
  final int page;
  final int totalPages;
  final int start;
  final int end;
  final int total;
}

Paged<T> paginate<T>(List<T> items, String key, int rowsPerPage, Map<String, int> pages) {
  final total = items.length;
  var totalPages = (total / rowsPerPage).ceil();
  if (totalPages < 1) totalPages = 1;

  var page = pages[key] ?? 1;
  if (page > totalPages) page = totalPages;
  if (page < 1) page = 1;

  final start = (page - 1) * rowsPerPage;
  var end = start + rowsPerPage;
  if (end > total) end = total;

  return Paged<T>(
    items: total == 0 ? <T>[] : items.sublist(start, end),
    page: page,
    totalPages: totalPages,
    start: start,
    end: end,
    total: total,
  );
}

Widget paginationBar(
  Paged paged,
  String key,
  String noun,
  Map<String, int> pages,
  void Function(String, int) onPageChange, {
  int currentRowsPerPage = 10,
  void Function(int)? onRowsPerPageChange,
}) {
  final showing = paged.total == 0
      ? 'No $noun'
      : 'Showing ${paged.start + 1}–${paged.end} of ${paged.total} $noun';

  final windowStart = (paged.page - 2).clamp(1, paged.totalPages).toInt();
  final windowEnd = (windowStart + 4).clamp(1, paged.totalPages).toInt();
  final adjustedStart = (windowEnd - 4).clamp(1, paged.totalPages).toInt();

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.65),
      border: Border(top: BorderSide(color: AppColors.borderColor.withValues(alpha: 0.6))),
    ),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 10,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onRowsPerPageChange != null) ...[
              const Text(
                'Rows per page:',
                style: TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.borderColor),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: [5, 10, 20, 50, 100].contains(currentRowsPerPage)
                        ? currentRowsPerPage
                        : 10,
                    isDense: true,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkText,
                    ),
                    icon: const Icon(Icons.arrow_drop_down, size: 18, color: AppColors.secondaryText),
                    items: const [
                      DropdownMenuItem(value: 5, child: Text('5')),
                      DropdownMenuItem(value: 10, child: Text('10')),
                      DropdownMenuItem(value: 20, child: Text('20')),
                      DropdownMenuItem(value: 50, child: Text('50')),
                      DropdownMenuItem(value: 100, child: Text('100')),
                    ],
                    onChanged: (val) {
                      if (val != null) onRowsPerPageChange(val);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 14),
            ],
            Text(
              showing,
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        Wrap(
          spacing: 4,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _pageArrow(
              Icons.keyboard_double_arrow_left,
              'First page',
              paged.page > 1,
              () => onPageChange(key, 1),
            ),
            _pageArrow(
              Icons.chevron_left,
              'Previous page',
              paged.page > 1,
              () => onPageChange(key, paged.page - 1),
            ),
            for (var p = adjustedStart; p <= windowEnd; p++)
              _pageNumber(p, p == paged.page, () => onPageChange(key, p)),
            _pageArrow(
              Icons.chevron_right,
              'Next page',
              paged.page < paged.totalPages,
              () => onPageChange(key, paged.page + 1),
            ),
            _pageArrow(
              Icons.keyboard_double_arrow_right,
              'Last page',
              paged.page < paged.totalPages,
              () => onPageChange(key, paged.totalPages),
            ),
          ],
        ),
      ],
    ),
  );
}

// Same 32x32 footprint as _pageNumber so arrows and number chips line up
// on the same row instead of the arrows looking oversized next to them.
Widget _pageArrow(
    IconData icon, String tooltip, bool enabled, VoidCallback onTap) {
  return SizedBox(
    width: 32,
    height: 32,
    child: IconButton(
      tooltip: tooltip,
      icon: Icon(icon, size: 16),
      splashRadius: 16,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      color: AppColors.secondaryText,
      disabledColor: AppColors.borderColor,
      onPressed: enabled ? onTap : null,
    ),
  );
}

Widget _pageNumber(int page, bool isActive, VoidCallback onTap) {
  // No inner Padding here — the parent Wrap's `spacing` supplies a
  // uniform gap between every pager element (arrows + numbers alike).
  return InkWell(
    borderRadius: BorderRadius.circular(8),
    onTap: isActive ? null : onTap,
    child: Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isActive ? AppColors.primaryOrange : Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive
              ? AppColors.primaryOrange
              : AppColors.borderColor.withValues(alpha: 0.8),
        ),
      ),
      child: Text(
        '$page',
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: isActive ? Colors.white : AppColors.secondaryText,
        ),
      ),
    ),
  );
}

class AdminUserAvatar extends StatelessWidget {
  final String? photoUrl;
  final String initials;
  final double radius;

  const AdminUserAvatar({
    super.key,
    this.photoUrl,
    required this.initials,
    this.radius = 17,
  });

  @override
  Widget build(BuildContext context) {
    ImageProvider? imageProvider;
    final trimmedUrl = photoUrl?.trim();
    if (trimmedUrl != null && trimmedUrl.isNotEmpty) {
      if (trimmedUrl.startsWith('http://') || trimmedUrl.startsWith('https://')) {
        imageProvider = NetworkImage(trimmedUrl);
      } else if (trimmedUrl.startsWith('data:image')) {
        final commaIdx = trimmedUrl.indexOf(',');
        if (commaIdx != -1) {
          try {
            final bytes = base64Decode(trimmedUrl.substring(commaIdx + 1));
            imageProvider = MemoryImage(bytes);
          } catch (_) {
            imageProvider = null;
          }
        }
      } else {
        try {
          final file = File(trimmedUrl);
          if (file.existsSync()) {
            imageProvider = FileImage(file);
          }
        } catch (_) {
          imageProvider = null;
        }
      }
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.lightPeach,
      backgroundImage: imageProvider,
      onBackgroundImageError: imageProvider != null
          ? (exception, stackTrace) {
              debugPrint('Failed to load user avatar image: $exception');
            }
          : null,
      child: imageProvider == null
          ? Text(
              initials,
              style: TextStyle(
                color: AppColors.primaryOrange,
                fontWeight: FontWeight.w700,
                fontSize: radius * 0.72,
              ),
            )
          : null,
    );
  }
}
