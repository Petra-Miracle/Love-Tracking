import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../data/api_client.dart';
import '../data/local_store.dart';
import '../models/models.dart';
import 'device_snapshot.dart';

const _notificationTitle = 'Love Tracking aktif 💕';
const _notificationSharing = 'Berbagi lokasi dengan pasangan';
const _notificationPaused = 'Berbagi lokasi sedang dijeda';

/// UI-side handle to the Android foreground service that uploads our status.
class TrackingService {
  final _service = FlutterBackgroundService();

  static Future<void> configure() async => FlutterBackgroundService().configure(
        androidConfiguration: AndroidConfiguration(
          onStart: trackingServiceEntryPoint,
          autoStart: false,
          // Android 14+ only allows a location service to start at boot with background location access.
          autoStartOnBoot: await Permission.locationAlways.isGranted,
          isForegroundMode: true,
          initialNotificationTitle: _notificationTitle,
          initialNotificationContent: _notificationSharing,
          foregroundServiceTypes: [AndroidForegroundType.location],
        ),
        iosConfiguration: IosConfiguration(autoStart: false),
      );

  Future<bool> isRunning() => _service.isRunning();

  Future<void> start() async {
    if (!await _service.isRunning()) await _service.startService();
  }

  Future<void> stop() async {
    if (await _service.isRunning()) _service.invoke('stop');
  }

  void setPaused(bool paused) => _service.invoke('setPaused', {'paused': paused});

  /// Asks the service to upload a fresh status right away.
  void flush() => _service.invoke('flush');

  /// Status snapshots produced by the service (our own live position/battery/network).
  Stream<DeviceStatus> get updates =>
      _service.on('update').where((e) => e != null).map((e) => DeviceStatus.fromJson(e!));
}

@pragma('vm:entry-point')
Future<void> trackingServiceEntryPoint(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  await _BackgroundTracker(service).run();
}

/// Runs inside the background-service isolate.
class _BackgroundTracker {
  _BackgroundTracker(this.service);

  final ServiceInstance service;
  final _store = const LocalStore();
  final _api = ApiClient();
  final _snapshot = DeviceSnapshot();

  /// Upload at most this often; position/battery/network changes in between are coalesced.
  static const _minInterval = Duration(seconds: 5);

  /// Gap for user actions (pause/resume, app opened) and 429 retries.
  /// The backend rejects more than one `PUT /status` per 2 seconds.
  static const _urgentInterval = Duration(seconds: 2);

  /// Keeps partner's view fresh (battery level, "last seen") while stationary.
  static const _heartbeat = Duration(seconds: 60);

  final _subs = <StreamSubscription<dynamic>>[];
  StreamSubscription<Position>? _positionSub;
  Timer? _heartbeatTimer;
  Timer? _pendingSend;
  DateTime? _pendingAt;
  Position? _position;
  bool _paused = false;
  bool _sending = false;
  bool _dirty = false;
  bool _stopped = false;
  DateTime _lastSent = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> run() async {
    _subs.add(service.on('stop').listen((_) => _stop()));
    _subs.add(service.on('flush').listen((_) => _requestSend(urgent: true)));
    _subs.add(service.on('setPaused').listen((e) => _setPaused(e?['paused'] == true)));

    if (await _store.readToken() == null) return _stop();
    if (!await _stillPaired()) return _stop();

    _paused = await _store.readSharingPaused();
    await _updateNotification();

    _subs.add(_snapshot.battery.onBatteryStateChanged.listen((_) => _requestSend()));
    _subs.add(_snapshot.connectivity.onConnectivityChanged.listen((_) => _requestSend()));
    _heartbeatTimer = Timer.periodic(_heartbeat, (_) {
      if (!_paused && _positionSub == null) _listenPosition();
      _requestSend();
    });

    if (!_paused) {
      _position = await Geolocator.getLastKnownPosition().catchError((_) => null);
      _listenPosition();
    }
    _requestSend();
  }

  /// Avoids tracking after an unpair/logout that happened while the app was closed
  /// (e.g. when the service is auto-started on boot).
  Future<bool> _stillPaired() async {
    try {
      return (await _api.me()).isPaired;
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        await _store.deleteToken();
        return false;
      }
      // Network/server problems: assume nothing changed and keep tracking.
      return true;
    }
  }

  void _listenPosition() {
    _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        intervalDuration: const Duration(seconds: 10),
      ),
    ).listen(
      (position) {
        _position = position;
        _requestSend();
      },
      onError: (Object e) {
        debugPrint('Location stream error: $e');
        _positionSub?.cancel();
        _positionSub = null; // the heartbeat retries
      },
    );
  }

  Future<void> _setPaused(bool paused) async {
    if (paused == _paused) return;
    _paused = paused;
    await _store.writeSharingPaused(paused);
    if (paused) {
      await _positionSub?.cancel();
      _positionSub = null;
    } else {
      _listenPosition();
    }
    await _updateNotification();
    _requestSend(urgent: true);
  }

  Future<void> _updateNotification() async {
    final s = service;
    if (s is AndroidServiceInstance) {
      await s.setForegroundNotificationInfo(
        title: _notificationTitle,
        content: _paused ? _notificationPaused : _notificationSharing,
      );
    }
  }

  /// Every upload goes through here, so uploads are always at least [_urgentInterval] apart.
  void _requestSend({bool urgent = false}) {
    _scheduleSend(_lastSent.add(urgent ? _urgentInterval : _minInterval));
  }

  void _scheduleSend(DateTime at) {
    if (_stopped) return;
    final pendingAt = _pendingAt;
    if (pendingAt != null && !pendingAt.isAfter(at)) return; // an earlier upload is already planned
    _pendingSend?.cancel();
    _pendingAt = at;
    final delay = at.difference(DateTime.now());
    _pendingSend = Timer(delay.isNegative ? Duration.zero : delay, () {
      _pendingSend = null;
      _pendingAt = null;
      _sendNow();
    });
  }

  Future<void> _sendNow() async {
    if (_stopped) return;
    if (_sending) {
      _dirty = true;
      return;
    }
    _sending = true;
    _lastSent = DateTime.now();
    var rateLimited = false;
    try {
      final status = await _snapshot.capture(position: _position, sharingPaused: _paused);
      service.invoke('update', status.toJson());
      await _api.putStatus(status);
    } on ApiException catch (e) {
      debugPrint('Status upload failed: $e');
      if (e.statusCode == 429) rateLimited = true;
      if (e.isUnauthorized) {
        await _store.deleteToken();
        return _stop();
      }
    } catch (e) {
      debugPrint('Status capture failed: $e');
    } finally {
      _sending = false;
      if (rateLimited) {
        // The snapshot is re-captured on retry, so it carries every change made meanwhile.
        _dirty = false;
        _scheduleSend(DateTime.now().add(_urgentInterval));
      } else if (_dirty && !_stopped) {
        _dirty = false;
        _requestSend();
      }
    }
  }

  Future<void> _stop() async {
    if (_stopped) return;
    _stopped = true;
    _heartbeatTimer?.cancel();
    _pendingSend?.cancel();
    await _positionSub?.cancel();
    for (final sub in _subs) {
      await sub.cancel();
    }
    await service.stopSelf();
  }
}
