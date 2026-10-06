import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:network_carrier/network_carrier.dart';

import '../models/models.dart';

/// Reads battery + network + carrier and combines them with a position into a [DeviceStatus].
class DeviceSnapshot {
  DeviceSnapshot({Battery? battery, Connectivity? connectivity})
      : battery = battery ?? Battery(),
        connectivity = connectivity ?? Connectivity();

  final Battery battery;
  final Connectivity connectivity;

  Future<DeviceStatus> capture({required Position? position, required bool sharingPaused}) async {
    final results = await Future.wait([
      _batteryLevel(),
      _batteryState(),
      connectivity.checkConnectivity().catchError((_) => <ConnectivityResult>[]),
    ]);
    final networkType = networkTypeOf(results[2] as List<ConnectivityResult>);
    final carrier = await NetworkCarrier.getCarrierInfo();
    final showLocation = position != null && !sharingPaused;

    return DeviceStatus(
      userId: '',
      lat: showLocation ? position.latitude : null,
      lng: showLocation ? position.longitude : null,
      accuracy: showLocation ? position.accuracy : null,
      speed: showLocation && position.speed >= 0 ? position.speed : null,
      heading: showLocation && position.heading >= 0 ? position.heading : null,
      battery: results[0] as int?,
      batteryState: results[1] as String,
      networkType: networkType,
      // The SIM operator is still interesting while on Wi-Fi, but the generation only matters on mobile data.
      carrier: carrier.carrier,
      mobileNetworkGen: networkType == 'mobile' ? carrier.generation : null,
      sharingPaused: sharingPaused,
      updatedAt: DateTime.now(),
    );
  }

  Future<int?> _batteryLevel() async {
    try {
      return await battery.batteryLevel;
    } catch (_) {
      return null;
    }
  }

  Future<String> _batteryState() async {
    try {
      return batteryStateName(await battery.batteryState);
    } catch (_) {
      return 'unknown';
    }
  }

  static String batteryStateName(BatteryState state) => switch (state) {
        BatteryState.charging => 'charging',
        BatteryState.discharging => 'discharging',
        BatteryState.full => 'full',
        _ => 'unknown',
      };

  /// Picks the connection that actually carries traffic; Wi-Fi wins over mobile.
  static String networkTypeOf(List<ConnectivityResult> results) {
    if (results.contains(ConnectivityResult.wifi)) return 'wifi';
    if (results.contains(ConnectivityResult.ethernet)) return 'ethernet';
    if (results.contains(ConnectivityResult.mobile)) return 'mobile';
    if (results.contains(ConnectivityResult.vpn)) return 'vpn';
    if (results.isEmpty || results.every((r) => r == ConnectivityResult.none)) return 'none';
    return 'other';
  }
}
