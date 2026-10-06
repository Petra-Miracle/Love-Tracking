import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../models/models.dart';
import 'format.dart';

/// Decides whether someone is really moving from how far their position travels,
/// not from the GPS-reported speed.
///
/// Indoors a phone's fix wanders 10–50 m back and forth and Android reports those
/// jumps as speed, so a person sitting still would look like they're walking.
/// Here movement only counts when the net displacement over the last minute clearly
/// exceeds the fixes' own inaccuracy.
class MovementEstimator {
  MovementEstimator({DateTime Function()? clock}) : _now = clock ?? DateTime.now;

  final DateTime Function() _now;
  final _samples = <_Sample>[];

  /// How far back positions are compared.
  static const window = Duration(seconds: 60);

  /// Too short a span makes a single GPS jump look like a sprint.
  static const minSpan = Duration(seconds: 20);

  /// Records [status] (once per distinct update) and returns the current movement.
  Movement? update(DeviceStatus? status) {
    if (status == null || !status.hasLocation) {
      _samples.clear();
      return null;
    }
    final last = _samples.isEmpty ? null : _samples.last;
    if (last == null || status.updatedAt.isAfter(last.time)) {
      _samples.add(_Sample(LatLng(status.lat!, status.lng!), status.updatedAt, status.accuracy));
    }

    final now = _now();
    _samples.removeWhere((s) => now.difference(s.time) > window);
    if (_samples.length < 2) return null;

    final first = _samples.first;
    final latest = _samples.last;
    final span = latest.time.difference(first.time);
    if (span < minSpan) return null;

    final distance = const Distance().as(LengthUnit.Meter, first.point, latest.point);
    final noise = 2 * math.max(first.accuracy, latest.accuracy) + 10;
    if (distance <= noise) return null;

    return movementForSpeed(distance / (span.inMilliseconds / 1000));
  }
}

class _Sample {
  _Sample(this.point, this.time, double? accuracy) : accuracy = (accuracy ?? 30).clamp(5, 100).toDouble();

  final LatLng point;
  final DateTime time;

  /// Meters; unknown accuracy is treated as a typical 30 m.
  final double accuracy;
}
