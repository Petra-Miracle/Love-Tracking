import 'package:flutter/services.dart';

class CarrierInfo {
  const CarrierInfo({this.carrier, this.generation});

  /// Operator name of the SIM used for mobile data, e.g. "Telkomsel".
  final String? carrier;

  /// "2G" | "3G" | "4G" | "5G", or null when unknown / READ_PHONE_STATE denied.
  final String? generation;
}

class NetworkCarrier {
  static const _channel = MethodChannel('network_carrier');

  static Future<CarrierInfo> getCarrierInfo() async {
    try {
      final map = await _channel.invokeMapMethod<String, String?>('getCarrierInfo');
      return CarrierInfo(carrier: map?['carrier'], generation: map?['generation']);
    } on PlatformException {
      return const CarrierInfo();
    } on MissingPluginException {
      return const CarrierInfo();
    }
  }
}
