import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Service managing device online/offline connectivity state
class ConnectivityService {
  ConnectivityService._internal() {
    _init();
  }
  static final ConnectivityService instance = ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  bool _isOnline = true;

  bool get isOnline => _isOnline;
  Stream<bool> get onConnectivityChanged => _controller.stream;

  void _init() {
    if (kIsWeb) {
      _isOnline = true;
      return;
    }

    try {
      _connectivity.checkConnectivity().then(_updateStatus).catchError((_) {
        // Fallback for test environment where platform channels are unmocked
        _isOnline = true;
      });
      _connectivity.onConnectivityChanged.listen((results) {
        _updateStatus(results);
      }, onError: (_) {});
    } catch (_) {
      _isOnline = true;
    }
  }

  void _updateStatus(List<ConnectivityResult> results) {
    final hasConnection = results.any((r) => r != ConnectivityResult.none);
    if (_isOnline != hasConnection) {
      _isOnline = hasConnection;
      _controller.add(_isOnline);
      debugPrint('[ConnectivityService] Connectivity state changed: isOnline = $_isOnline');
    }
  }

  @visibleForTesting
  void setOnlineForTesting(bool value) {
    _isOnline = value;
    _controller.add(_isOnline);
  }

  void dispose() {
    _controller.close();
  }
}
