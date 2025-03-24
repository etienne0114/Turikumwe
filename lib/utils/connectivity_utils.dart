import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityUtils {
  static final Connectivity _connectivity = Connectivity();

  /// Check if the device is connected to the internet
  static Future<bool> isConnected() async {
    final connectivityResult = await _connectivity.checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  /// Get the current connectivity status
  static Future<ConnectivityResult> getConnectivityStatus() async {
    return await _connectivity.checkConnectivity();
  }

  /// Stream of connectivity changes
  static Stream<ConnectivityResult> get onConnectivityChanged {
    return _connectivity.onConnectivityChanged;
  }

  /// Check if the device is connected to WiFi
  static Future<bool> isConnectedToWifi() async {
    final connectivityResult = await _connectivity.checkConnectivity();
    return connectivityResult == ConnectivityResult.wifi;
  }

  /// Check if the device is connected to mobile network
  static Future<bool> isConnectedToMobile() async {
    final connectivityResult = await _connectivity.checkConnectivity();
    return connectivityResult == ConnectivityResult.mobile;
  }

  /// Get a human-readable connectivity status
  static String getConnectivityStatusString(ConnectivityResult result) {
    switch (result) {
      case ConnectivityResult.wifi:
        return 'WiFi';
      case ConnectivityResult.mobile:
        return 'Mobile Data';
      case ConnectivityResult.ethernet:
        return 'Ethernet';
      case ConnectivityResult.bluetooth:
        return 'Bluetooth';
      case ConnectivityResult.none:
        return 'No Internet';
      default:
        return 'Unknown';
    }
  }
}
