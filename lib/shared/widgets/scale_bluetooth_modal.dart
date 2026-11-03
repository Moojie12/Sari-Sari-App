import 'dart:async';
import 'package:bluetooth_classic/models/device.dart';
import 'package:flutter/material.dart';

import '../../core/services/scale_bluetooth_service.dart';
import '../../core/theme/app_colors.dart';
import '../utils/top_notification.dart';

/// Shows an interactive bottom sheet for connecting to and controlling
/// the Bluetooth scale ("Timbangan_Ni_Eca").
///
/// Can be invoked anywhere in the app (e.g. Add Product in Inventory, POS, Cart).
Future<void> showScaleBluetoothModal(
  BuildContext context, {
  VoidCallback? onConnectionChanged,
}) async {
  final scale = ScaleBluetoothService.instance;
  List<Device> devices = [];
  bool isLoadingDevices = true;
  String? localError;
  bool isConnecting = false;
  bool isTaring = false;
  bool isReadingWeight = false;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (modalContext, setModalState) {
          if (isLoadingDevices) {
            scale.getPairedDevices().then((list) {
              if (!modalContext.mounted) return;
              setModalState(() {
                devices = list;
                isLoadingDevices = false;
              });
            }).catchError((e) {
              if (!modalContext.mounted) return;
              setModalState(() {
                localError = e.toString();
                isLoadingDevices = false;
              });
            });
          }

          Device? scaleDevice;
          for (final d in devices) {
            final n = (d.name ?? '').toLowerCase();
            if (d.name == 'Timbangan_Ni_Eca' ||
                d.name == 'SmartScale_IoT' ||
                n.contains('timbangan') ||
                n.contains('smartscale')) {
              scaleDevice = d;
              break;
            }
          }

          final isConnected = scale.isConnected;

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isConnected
                                    ? Colors.teal.withValues(alpha: 0.12)
                                    : AppColors.primaryOrange.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                isConnected
                                    ? Icons.bluetooth_connected
                                    : Icons.bluetooth_searching,
                                color: isConnected ? Colors.teal : AppColors.primaryOrange,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Bluetooth Scale',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.darkText,
                                  ),
                                ),
                                Text(
                                  isConnected
                                      ? 'Connected: ${scale.connectedDeviceName ?? "Timbangan Ni Eca"}'
                                      : 'Find & Connect to Timbangan Ni Eca',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isConnected ? Colors.teal : AppColors.secondaryText,
                                    fontWeight: isConnected ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: AppColors.secondaryText),
                          onPressed: () => Navigator.pop(sheetContext),
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    // Loading State
                    if (isLoadingDevices) ...[
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 30),
                          child: Column(
                            children: [
                              CircularProgressIndicator(color: AppColors.primaryOrange),
                              SizedBox(height: 12),
                              Text(
                                'Searching paired devices for Timbangan Ni Eca...',
                                style: TextStyle(color: AppColors.secondaryText, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else if (localError != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(
                          localError!,
                          style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                        ),
                      ),
                    ] else ...[
                      // Found Timbangan Device Card
                      if (scaleDevice != null) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isConnected ? Colors.teal.shade50 : Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isConnected ? Colors.teal : AppColors.primaryOrange,
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.scale,
                                    color: isConnected ? Colors.teal : AppColors.primaryOrange,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          scaleDevice.name ?? 'Timbangan_Ni_Eca',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                        ),
                                        Text(
                                          scaleDevice.address,
                                          style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isConnected ? Colors.teal : Colors.orange,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      isConnected ? 'CONNECTED' : 'FOUND',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),

                              // Connect / Disconnect Action Button
                              SizedBox(
                                width: double.infinity,
                                height: 44,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isConnected ? Colors.red.shade600 : AppColors.primaryOrange,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  icon: isConnecting
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                      : Icon(
                                          isConnected ? Icons.bluetooth_disabled : Icons.bluetooth_connected,
                                          size: 18,
                                        ),
                                  label: Text(
                                    isConnecting
                                        ? 'Connecting...'
                                        : (isConnected ? 'Disconnect Scale' : 'Connect to Timbangan Ni Eca'),
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  onPressed: isConnecting
                                      ? null
                                      : () async {
                                          if (isConnected) {
                                            scale.disconnect();
                                            setModalState(() {});
                                            onConnectionChanged?.call();
                                            TopNotification.show(context, 'Scale disconnected.');
                                          } else {
                                            setModalState(() => isConnecting = true);
                                            final err = await scale.connectToDevice(scaleDevice!);
                                            if (!modalContext.mounted) return;
                                            setModalState(() => isConnecting = false);
                                            onConnectionChanged?.call();
                                            if (err != null) {
                                              TopNotification.show(modalContext, err, isError: true);
                                            } else {
                                              TopNotification.show(modalContext, 'Connected to Timbangan Ni Eca!');
                                              await Future.delayed(const Duration(milliseconds: 600));
                                              if (modalContext.mounted) Navigator.pop(sheetContext);
                                            }
                                          }
                                        },
                                ),
                              ),

                              // Quick Scale Controls (If Connected)
                              if (isConnected) ...[
                                const SizedBox(height: 12),
                                const Divider(),
                                const SizedBox(height: 8),
                                const Text(
                                  'QUICK SCALE ACTIONS',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.labelText,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppColors.primaryOrange,
                                          side: const BorderSide(color: AppColors.primaryOrange),
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        icon: isTaring
                                            ? const SizedBox(
                                                width: 14,
                                                height: 14,
                                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryOrange),
                                              )
                                            : const Text(
                                                'T',
                                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                                              ),
                                        label: const Text('Tare (0.00 kg)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                        onPressed: (isTaring || isReadingWeight)
                                            ? null
                                            : () async {
                                                setModalState(() => isTaring = true);
                                                final sent = await scale.sendTare();
                                                await Future.delayed(const Duration(milliseconds: 400));
                                                if (modalContext.mounted) {
                                                  setModalState(() => isTaring = false);
                                                  if (sent) {
                                                    TopNotification.show(modalContext, 'Scale tared to 0.00 kg');
                                                  } else {
                                                    TopNotification.show(modalContext, 'Failed to tare scale.', isError: true);
                                                  }
                                                }
                                              },
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.teal,
                                          side: const BorderSide(color: Colors.teal),
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        icon: isReadingWeight
                                            ? const SizedBox(
                                                width: 14,
                                                height: 14,
                                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.teal),
                                              )
                                            : const Icon(Icons.scale, size: 16),
                                        label: const Text('Read Weight', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                        onPressed: (isTaring || isReadingWeight)
                                            ? null
                                            : () async {
                                                setModalState(() => isReadingWeight = true);
                                                final sent = await scale.requestWeight();
                                                await Future.delayed(const Duration(milliseconds: 600));
                                                if (modalContext.mounted) {
                                                  setModalState(() => isReadingWeight = false);
                                                  if (sent && scale.lastWeight != null) {
                                                    TopNotification.show(
                                                      modalContext,
                                                      'Current reading: ${scale.lastWeight!.toStringAsFixed(2)} kg ${scale.lastIsLocked ? "[LOCKED]" : ""}',
                                                    );
                                                  }
                                                }
                                              },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ] else ...[
                        // Not paired yet in phone settings
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.amber.shade400),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 22),
                                  SizedBox(width: 8),
                                  Text(
                                    '"Timbangan_Ni_Eca" Not Found',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Make sure the weighing scale is ON and paired in your phone\'s Bluetooth Settings.',
                                style: TextStyle(fontSize: 12, color: AppColors.darkText),
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primaryOrange,
                                  side: const BorderSide(color: AppColors.primaryOrange),
                                ),
                                icon: const Icon(Icons.refresh, size: 16),
                                label: const Text('Refresh Paired Devices'),
                                onPressed: () {
                                  setModalState(() => isLoadingDevices = true);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Other paired devices
                      if (devices.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: Text(
                            'All Paired Devices (${devices.length})',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.labelText,
                            ),
                          ),
                          children: devices.map((d) {
                            final isTarget = d.name == 'Timbangan_Ni_Eca';
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                isTarget ? Icons.scale : Icons.bluetooth,
                                color: isTarget ? AppColors.primaryOrange : AppColors.secondaryText,
                              ),
                              title: Text(
                                d.name ?? 'Unknown Device',
                                style: TextStyle(fontWeight: isTarget ? FontWeight.bold : FontWeight.normal),
                              ),
                              subtitle: Text(d.address, style: const TextStyle(fontSize: 11)),
                              trailing: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isTarget ? AppColors.primaryOrange : Colors.grey.shade300,
                                  foregroundColor: isTarget ? Colors.white : Colors.black87,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                ),
                                onPressed: isConnecting
                                    ? null
                                    : () async {
                                        setModalState(() => isConnecting = true);
                                        final err = await scale.connectToDevice(d);
                                        if (!modalContext.mounted) return;
                                        setModalState(() => isConnecting = false);
                                        onConnectionChanged?.call();
                                        if (err != null) {
                                          TopNotification.show(modalContext, err, isError: true);
                                        } else {
                                          TopNotification.show(modalContext, 'Connected to ${d.name ?? "device"}!');
                                          Navigator.pop(sheetContext);
                                        }
                                      },
                                child: const Text('Connect', style: TextStyle(fontSize: 11)),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}
