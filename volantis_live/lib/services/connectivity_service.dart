import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Service to check network connectivity status
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();

  /// Stream controller for connectivity changes (bool)
  final StreamController<bool> _connectionChangeController =
      StreamController<bool>.broadcast();

  /// Stream controller for detailed connectivity results
  final StreamController<ConnectivityResult> _connectivityResultController =
      StreamController<ConnectivityResult>.broadcast();

  /// Current connectivity status (null = unknown/not checked yet)
  bool? _isConnected;

  /// Initialize and start listening to connectivity changes
  Future<void> init() async {
    // Get initial connectivity status
    final result = await _connectivity.checkConnectivity();
    _updateConnectionStatus(result);

    // Listen for changes
    _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
  }

  void _updateConnectionStatus(ConnectivityResult result) {
    final wasConnected = _isConnected;
    _isConnected = result != ConnectivityResult.none;

    // Notify listeners only if status changed
    if (wasConnected != _isConnected) {
      _connectionChangeController.add(_isConnected ?? false);
    }

    // Always emit connectivity result for detailed status tracking
    _lastConnectivityResult = result;
    _connectivityResultController.add(result);
  }

  /// Check if device is currently connected to the internet
  /// Returns cached value if available, otherwise checks fresh
  Future<bool> isConnected() async {
    if (_isConnected != null) return _isConnected!;

    final result = await _connectivity.checkConnectivity();
    _updateConnectionStatus(result);
    return _isConnected ?? false;
  }

  /// Stream of connectivity changes (true = connected, false = offline)
  Stream<bool> get onConnectivityChanged => _connectionChangeController.stream;

  /// Stream of detailed connectivity results (WiFi, mobile, ethernet, etc.)
  Stream<ConnectivityResult> get onConnectivityResultChanged =>
      _connectivityResultController.stream;

  /// Get current connection status synchronously (may be null)
  bool? get currentStatus => _isConnected;

  /// Get the last connectivity result (WiFi, mobile, ethernet, etc.)
  /// Returns null if not initialized yet
  ConnectivityResult? _lastConnectivityResult;

  /// Get current connectivity result
  ConnectivityResult? get currentConnectivityResult => _lastConnectivityResult;

  /// Dispose resources
  void dispose() {
    _connectionChangeController.close();
    _connectivityResultController.close();
  }
}
