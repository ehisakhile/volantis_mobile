import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:rxdart/rxdart.dart';

/// Service to monitor and handle network connectivity
class ConnectivityService {
  static ConnectivityService? _instance;
  final Connectivity _connectivity = Connectivity();
  
  final BehaviorSubject<ConnectivityStatus> _statusController =
      BehaviorSubject<ConnectivityStatus>.seeded(ConnectivityStatus.unknown);
  
  StreamSubscription<ConnectivityResult>? _subscription;

  ConnectivityService._() {
    _init();
  }

  static ConnectivityService get instance {
    _instance ??= ConnectivityService._();
    return _instance!;
  }

  void _init() {
    _checkConnectivity();
    _subscription = _connectivity.onConnectivityChanged.listen(_updateStatus);
  }

  Future<void> _checkConnectivity() async {
    final result = await _connectivity.checkConnectivity();
    _updateStatus(result);
  }

  void _updateStatus(ConnectivityResult result) {
    switch (result) {
      case ConnectivityResult.none:
        _statusController.add(ConnectivityStatus.offline);
        break;
      case ConnectivityResult.mobile:
        _statusController.add(ConnectivityStatus.mobile);
        break;
      case ConnectivityResult.wifi:
        _statusController.add(ConnectivityStatus.wifi);
        break;
      case ConnectivityResult.ethernet:
        _statusController.add(ConnectivityStatus.ethernet);
        break;
      case ConnectivityResult.vpn:
        _statusController.add(ConnectivityStatus.vpn);
        break;
      default:
        _statusController.add(ConnectivityStatus.unknown);
    }
  }

  /// Stream of connectivity status
  Stream<ConnectivityStatus> get statusStream => _statusController.stream;

  /// Current connectivity status
  ConnectivityStatus get currentStatus => _statusController.value;

  /// Check if connected to the internet
  bool get isConnected =>
      currentStatus != ConnectivityStatus.offline &&
      currentStatus != ConnectivityStatus.unknown;

  /// Check if connected to WiFi
  bool get isWifi => currentStatus == ConnectivityStatus.wifi;

  /// Check if connected to mobile data
  bool get isMobile => currentStatus == ConnectivityStatus.mobile;

  /// Get quality rating based on connection type
  NetworkQuality get networkQuality {
    switch (currentStatus) {
      case ConnectivityStatus.wifi:
        return NetworkQuality.excellent;
      case ConnectivityStatus.ethernet:
        return NetworkQuality.excellent;
      case ConnectivityStatus.vpn:
        return NetworkQuality.good;
      case ConnectivityStatus.mobile:
        return NetworkQuality.fair;
      case ConnectivityStatus.offline:
        return NetworkQuality.noConnection;
      case ConnectivityStatus.unknown:
        return NetworkQuality.unknown;
    }
  }

  /// Dispose
  void dispose() {
    _subscription?.cancel();
    _statusController.close();
  }
}

/// Connectivity status enum
enum ConnectivityStatus {
  unknown,
  offline,
  wifi,
  mobile,
  ethernet,
  vpn,
}

/// Network quality enum
enum NetworkQuality {
  unknown,
  noConnection,
  poor,
  fair,
  good,
  excellent,
}

/// Extension to get human-readable status
extension ConnectivityStatusExtension on ConnectivityStatus {
  String get displayName {
    switch (this) {
      case ConnectivityStatus.unknown:
        return 'Unknown';
      case ConnectivityStatus.offline:
        return 'Offline';
      case ConnectivityStatus.wifi:
        return 'WiFi';
      case ConnectivityStatus.mobile:
        return 'Mobile Data';
      case ConnectivityStatus.ethernet:
        return 'Ethernet';
      case ConnectivityStatus.vpn:
        return 'VPN';
    }
  }

  bool get isConnected => this != ConnectivityStatus.offline && this != ConnectivityStatus.unknown;
}

/// Extension for network quality
extension NetworkQualityExtension on NetworkQuality {
  String get displayName {
    switch (this) {
      case NetworkQuality.unknown:
        return 'Unknown';
      case NetworkQuality.noConnection:
        return 'No Connection';
      case NetworkQuality.poor:
        return 'Poor';
      case NetworkQuality.fair:
        return 'Fair';
      case NetworkQuality.good:
        return 'Good';
      case NetworkQuality.excellent:
        return 'Excellent';
    }
  }

  /// Get recommended audio quality based on network
  String get recommendedAudioQuality {
    switch (this) {
      case NetworkQuality.unknown:
      case NetworkQuality.noConnection:
      case NetworkQuality.poor:
        return 'low';
      case NetworkQuality.fair:
        return 'medium';
      case NetworkQuality.good:
      case NetworkQuality.excellent:
        return 'high';
    }
  }
}