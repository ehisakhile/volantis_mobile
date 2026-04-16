import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Service to check network connectivity status
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();

  factory ConnectivityService() => _instance;

  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  /// Stream controller for connectivity changes (bool)
  final StreamController<bool> _connectionChangeController =
      StreamController<bool>.broadcast();

  /// Stream controller for detailed connectivity results
  final StreamController<List<ConnectivityResult>>
  _connectivityResultController =
      StreamController<List<ConnectivityResult>>.broadcast();

  /// Current connectivity status (null = unknown/not checked yet)
  bool? _isConnected;

  /// Last detailed connectivity result
  List<ConnectivityResult>? _lastConnectivityResults;

  /// Initialize and start listening to connectivity changes
  Future<void> init() async {
    // Cancel any existing subscription before creating a new one
    await _connectivitySubscription?.cancel();

    // Get initial connectivity status
    final result = await _connectivity.checkConnectivity();
    _updateConnectionStatus(result);

    // Listen for changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (result) => _updateConnectionStatus(result),
      onError: (_) {
        _updateConnectionStatus([ConnectivityResult.none]);
      },
    );
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    final normalizedResults = results.isEmpty
        ? <ConnectivityResult>[ConnectivityResult.none]
        : results;

    final wasConnected = _isConnected;
    _isConnected = !_hasNoConnection(normalizedResults);

    // Notify listeners only if status changed
    if (wasConnected != _isConnected && !_connectionChangeController.isClosed) {
      _connectionChangeController.add(_isConnected ?? false);
    }

    // Always emit connectivity result for detailed status tracking
    _lastConnectivityResults = normalizedResults;
    if (!_connectivityResultController.isClosed) {
      _connectivityResultController.add(normalizedResults);
    }
  }

  bool _hasNoConnection(List<ConnectivityResult> results) {
    return results.length == 1 && results.first == ConnectivityResult.none;
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
  Stream<List<ConnectivityResult>> get onConnectivityResultChanged =>
      _connectivityResultController.stream;

  /// Get current connection status synchronously (may be null)
  bool? get currentStatus => _isConnected;

  /// Get the last connectivity results
  /// Returns null if not initialized yet
  List<ConnectivityResult>? get currentConnectivityResults =>
      _lastConnectivityResults;

  /// Convenience getter for primary/current connectivity result
  /// Falls back to [ConnectivityResult.none] if nothing is available
  ConnectivityResult get currentConnectivityResult {
    if (_lastConnectivityResults == null || _lastConnectivityResults!.isEmpty) {
      return ConnectivityResult.none;
    }
    return _lastConnectivityResults!.first;
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _connectivitySubscription?.cancel();
    await _connectionChangeController.close();
    await _connectivityResultController.close();
  }
}
