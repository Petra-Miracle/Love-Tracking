import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../models/models.dart';
import 'theme.dart';

String timeAgo(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inSeconds < 45) return 'baru saja';
  if (diff.inMinutes < 60) return '${diff.inMinutes.clamp(1, 59)} menit lalu';
  if (diff.inHours < 24) return '${diff.inHours} jam lalu';
  return '${diff.inDays} hari lalu';
}

/// Indonesian 24-hour clock, e.g. "14.30".
String formatClock(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}.${time.minute.toString().padLeft(2, '0')}';

String formatDistance(double meters) {
  if (meters < 1000) return '${meters.round()} m';
  final km = meters / 1000;
  return '${km.toStringAsFixed(km < 10 ? 1 : 0).replaceAll('.', ',')} km';
}

/// Null when the person is (nearly) stationary.
String? formatSpeed(double? metersPerSecond) {
  if (metersPerSecond == null || metersPerSecond < 1) return null;
  return '${(metersPerSecond * 3.6).round()} km/j';
}

IconData batteryIcon(DeviceStatus s) {
  if (s.batteryState == 'charging' || s.batteryState == 'full') return Symbols.battery_charging_full_rounded;
  final level = s.battery ?? -1;
  if (level < 0) return Symbols.battery_unknown_rounded;
  if (level <= 15) return Symbols.battery_alert_rounded;
  if (level <= 35) return Symbols.battery_2_bar_rounded;
  if (level <= 60) return Symbols.battery_4_bar_rounded;
  if (level <= 85) return Symbols.battery_5_bar_rounded;
  return Symbols.battery_full_rounded;
}

Color batteryColor(DeviceStatus s, ColorScheme scheme) {
  if (s.batteryState == 'charging' || s.batteryState == 'full') return AppColors.success(scheme.brightness);
  final level = s.battery;
  if (level != null && level <= 15) return scheme.error;
  return scheme.onSurfaceVariant;
}

String batteryLabel(DeviceStatus s) {
  final level = s.battery == null ? '?' : '${s.battery}%';
  return switch (s.batteryState) {
    'charging' => '$level · mengisi',
    'full' => '$level · penuh',
    _ => level,
  };
}

IconData networkIcon(DeviceStatus s) => switch (s.networkType) {
      'wifi' => Symbols.wifi_rounded,
      'mobile' => Symbols.signal_cellular_alt_rounded,
      'ethernet' => Symbols.settings_ethernet_rounded,
      'vpn' => Symbols.vpn_lock_rounded,
      'none' => Symbols.signal_cellular_off_rounded,
      _ => Symbols.public_rounded,
    };

String networkLabel(DeviceStatus s) => switch (s.networkType) {
      'wifi' => 'Wi-Fi',
      'mobile' => [s.carrier ?? 'Data seluler', ?s.mobileNetworkGen].join(' '),
      'ethernet' => 'Ethernet',
      'vpn' => 'VPN',
      'none' => 'Offline',
      _ => 'Internet',
    };
