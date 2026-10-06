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

enum Movement { walking, running, traveling }

/// How someone is moving, from their GPS speed; null when (nearly) standing still,
/// paused, or when [stale] data can't say anything about the present.
Movement? movementOf(DeviceStatus? s, {bool stale = false}) {
  final speed = s?.speed;
  if (s == null || stale || !s.hasLocation || speed == null || speed < 0.8) return null; // < ~3 km/h
  if (speed < 2.2) return Movement.walking; // < ~8 km/h
  if (speed < 4.5) return Movement.running; // < ~16 km/h
  return Movement.traveling;
}

IconData movementIcon(Movement m) => switch (m) {
      Movement.walking => Symbols.directions_walk_rounded,
      Movement.running => Symbols.directions_run_rounded,
      Movement.traveling => Symbols.directions_car_rounded,
    };

String movementLabel(Movement m) => switch (m) {
      Movement.walking => 'Sedang berjalan',
      Movement.running => 'Sedang berlari',
      Movement.traveling => 'Dalam perjalanan',
    };

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

/// Builds an Indonesian-style address ("Jl. Sudirman No. 1, Senayan, Kebayoran Baru,
/// Kota Jakarta Selatan, DKI Jakarta 12190"), skipping empty and repeated parts.
String? formatAddress({
  String? street,
  String? subLocality,
  String? locality,
  String? subAdministrativeArea,
  String? administrativeArea,
  String? postalCode,
}) {
  final parts = <String>[];
  for (final raw in [street, subLocality, locality, subAdministrativeArea, administrativeArea]) {
    final part = raw?.trim() ?? '';
    // Geocoders sometimes return plus codes (e.g. "8Q7X+2F") instead of a street.
    if (part.isEmpty || part.contains('+')) continue;
    if (parts.any((p) => p.toLowerCase().contains(part.toLowerCase()))) continue;
    parts.add(part);
  }
  if (parts.isEmpty) return null;
  final code = postalCode?.trim() ?? '';
  if (code.isNotEmpty && !parts.last.contains(code)) parts[parts.length - 1] = '${parts.last} $code';
  return parts.join(', ');
}
