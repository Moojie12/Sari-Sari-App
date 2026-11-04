import 'dart:async';
import 'dart:convert';
import 'package:bluetooth_classic/bluetooth_classic.dart';
import 'package:bluetooth_classic/models/device.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class ScaleBluetoothService extends ChangeNotifier {
  ScaleBluetoothService._() {
    _initStreams();
  }
  static final ScaleBluetoothService instance = ScaleBluetoothService._();

  final BluetoothClassic _bluetooth = BluetoothClassic();
  StreamSubscription<Uint8List>? _dataSubscription;
  StreamSubscription<int>? _statusSubscription;

  bool _isConnected = false;
  String? _connectedDeviceName;
  String _incomingBuffer = '';
  double? _lastWeight;
  bool _lastIsLocked = false;

  bool get isConnected => _isConnected;
  String? get connectedDeviceName => _connectedDeviceName;
  double? get lastWeight => _lastWeight;
  bool get lastIsLocked => _lastIsLocked;

  Function(double weight, bool isLocked)? onWeightReceived;
  Function()? onTared;
  Function(bool isConnected)? onConnectionChanged;

  // Standard SPP UUID used by ESP32 BluetoothSerial
  static const String sppUuid = "00001101-0000-1000-8000-00805f9b34fb";

  /// Initialize event streams once during service lifetime.
  /// Subscribing once avoids "Bad state: Stream has already been listened to" errors.
  void _initStreams() {
    try {
      _statusSubscription = _bluetooth.onDeviceStatusChanged().listen((status) {
        debugPrint('Bluetooth device status event: $status');
        if (status == Device.connected) {
          _isConnected = true;
          notifyListeners();
          onConnectionChanged?.call(true);
        } else if (status == Device.disconnected) {
          _isConnected = false;
          _connectedDeviceName = null;
          notifyListeners();
          onConnectionChanged?.call(false);
        }
      }, onError: (e) {
        debugPrint('Bluetooth status stream error: $e');
      });

      _dataSubscription = _bluetooth.onDeviceDataReceived().listen(
        _handleIncomingBytes,
        onError: (e) {
          debugPrint('Bluetooth data stream error: $e');
        },
      );
    } catch (e) {
      debugPrint('Error initializing Bluetooth streams: $e');
    }
  }

  /// Get list of paired / bonded devices from phone settings
  Future<List<Device>> getPairedDevices() async {
    try {
      if (await Permission.bluetoothConnect.status.isDenied) {
        await Permission.bluetoothConnect.request();
      }
      return await _bluetooth.getPairedDevices();
    } catch (e) {
      debugPrint('Error getting paired devices: $e');
      return [];
    }
  }

  /// Connect to a specific device directly
  Future<String?> connectToDevice(Device device) async {
    try {
      // 1. Request Runtime Permissions (Nearby Devices on Android 12+)
      try {
        if (await Permission.bluetoothConnect.status.isDenied) {
          await Permission.bluetoothConnect.request();
        }
        if (await Permission.bluetoothScan.status.isDenied) {
          await Permission.bluetoothScan.request();
        }
      } catch (e) {
        debugPrint('Bluetooth permission check error: $e');
      }

      if (await Permission.bluetoothConnect.isPermanentlyDenied) {
        return 'Please allow "Nearby devices" permission in App Settings.';
      }

      disconnect();
      _incomingBuffer = '';

      debugPrint('Connecting to ${device.name} at ${device.address}...');
      final success = await _bluetooth.connect(device.address, sppUuid);
      if (success) {
        _isConnected = true;
        _connectedDeviceName = device.name ?? 'Timbangan_Ni_Eca';
        notifyListeners();
        onConnectionChanged?.call(true);
        debugPrint('Connected successfully to ${device.name}!');
        return null; // Success!
      } else {
        disconnect();
        return 'Could not connect to "${device.name}".\nMake sure the scale is ON and not connected to another phone.';
      }
    } catch (e) {
      disconnect();
      return 'Could not connect: $e';
    }
  }

  /// Auto-find and connect to "Timbangan_Ni_Eca"
  Future<String?> connect() async {
    try {
      final bondedDevices = await getPairedDevices();
      debugPrint('Found ${bondedDevices.length} paired devices.');

      Device? scaleDevice;
      for (final device in bondedDevices) {
        final name = device.name ?? '';
        final lower = name.toLowerCase();
        debugPrint('Checking paired device: "$name" (${device.address})');
        if (name == 'Timbangan_Ni_Eca' ||
            name == 'SmartScale_IoT' ||
            lower.contains('timbangan') ||
            lower.contains('smartscale')) {
          scaleDevice = device;
          break;
        }
      }

      if (scaleDevice == null) {
        return 'Could not find "Timbangan_Ni_Eca" in paired devices.\nPlease pair it in your phone\'s Bluetooth Settings first.';
      }

      return await connectToDevice(scaleDevice);
    } catch (e) {
      disconnect();
      return 'Could not connect: $e';
    }
  }

  void _handleIncomingBytes(Uint8List data) {
    try {
      final chunk = utf8.decode(data, allowMalformed: true);
      _incomingBuffer += chunk;
      debugPrint('Scale Bluetooth Raw Data: $chunk');

      _parseBuffer();
    } catch (e) {
      debugPrint('Error decoding scale bluetooth data: $e');
    }
  }

  void _parseBuffer() {
    // 1. JSON extraction: match any complete JSON object {...}
    final jsonRegex = RegExp(r'\{[^{}]*\}');
    var match = jsonRegex.firstMatch(_incomingBuffer);
    while (match != null) {
      final jsonStr = match.group(0)!;
      final endIndex = match.end;
      _incomingBuffer = _incomingBuffer.substring(endIndex);

      _processJsonString(jsonStr);
      match = jsonRegex.firstMatch(_incomingBuffer);
    }

    // 2. Newline or fragmented extraction: handles lines or fragments
    while (_incomingBuffer.contains('\n')) {
      final index = _incomingBuffer.indexOf('\n');
      final line = _incomingBuffer.substring(0, index).trim();
      _incomingBuffer = _incomingBuffer.substring(index + 1);

      if (line.isNotEmpty) {
        _processPlainLine(line);
      }
    }

    // Guard against buffer overflow
    if (_incomingBuffer.length > 2000) {
      _incomingBuffer = _incomingBuffer.substring(_incomingBuffer.length - 500);
    }
  }

  void _processJsonString(String jsonStr) {
    debugPrint('Scale Bluetooth Parsed JSON: $jsonStr');
    try {
      final Map<String, dynamic> json = jsonDecode(jsonStr);
      if (json.containsKey('weight')) {
        final double weight = (json['weight'] as num).toDouble();
        final bool isLocked = json['isLocked'] == true;
        _lastWeight = weight;
        _lastIsLocked = isLocked;
        notifyListeners();
        onWeightReceived?.call(weight, isLocked);
      } else if (json['status'] == 'TARED') {
        _lastWeight = 0.0;
        _lastIsLocked = false;
        notifyListeners();
        onTared?.call();
      }
    } catch (e) {
      debugPrint('Error parsing JSON string "$jsonStr": $e');
    }
  }

  void _processPlainLine(String line) {
    debugPrint('Scale Bluetooth Parsed Line: $line');

    // 1. Check if tare response
    if (line.toUpperCase().contains('TARED')) {
      _lastWeight = 0.0;
      _lastIsLocked = false;
      notifyListeners();
      onTared?.call();
      return;
    }

    // 2. Try direct number parse e.g. "78.14"
    var weight = double.tryParse(line);
    if (weight != null) {
      _lastWeight = weight;
      _lastIsLocked = true;
      notifyListeners();
      onWeightReceived?.call(weight, true);
      return;
    }

    // 3. Fallback regex to match weight numbers even in fragmented strings
    // like: 78.140,"isLocked":false}
    final match = RegExp(r'(\d+\.\d+)').firstMatch(line);
    if (match != null) {
      weight = double.tryParse(match.group(1)!);
      if (weight != null) {
        final isLocked = line.toLowerCase().contains('locked":true');
        _lastWeight = weight;
        _lastIsLocked = isLocked;
        notifyListeners();
        onWeightReceived?.call(weight, isLocked);
      }
    }
  }

  /// Send Tare command 't' to ESP32
  Future<bool> sendTare() async {
    if (!isConnected) return false;
    try {
      debugPrint('Scale Bluetooth: Sending Tare ("t")');
      return await _bluetooth.write('t\n');
    } catch (e) {
      debugPrint('Error sending tare: $e');
      return false;
    }
  }

  /// Send Request Weight command 'w' to ESP32
  Future<bool> requestWeight() async {
    if (!isConnected) return false;
    try {
      debugPrint('Scale Bluetooth: Requesting Weight ("w")');
      return await _bluetooth.write('w\n');
    } catch (e) {
      debugPrint('Error requesting weight: $e');
      return false;
    }
  }

  /// Disconnect
  void disconnect() {
    _isConnected = false;
    _connectedDeviceName = null;
    try {
      _bluetooth.disconnect();
    } catch (e) {
      debugPrint('Error disconnecting bluetooth: $e');
    }
    notifyListeners();
    onConnectionChanged?.call(false);
  }

  /// Clean up streams if service is destroyed
  @override
  void dispose() {
    disconnect();
    _dataSubscription?.cancel();
    _statusSubscription?.cancel();
    super.dispose();
  }
}

