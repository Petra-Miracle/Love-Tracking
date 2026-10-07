import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Locale, ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:permission_handler/permission_handler.dart';

import 'config.dart';
import 'data/api_client.dart';
import 'data/local_store.dart';
import 'models/models.dart';
import 'services/realtime_service.dart';
import 'services/tracking_service.dart';
import 'ui/format.dart';

final localStoreProvider = Provider((ref) => const LocalStore());
final apiClientProvider = Provider((ref) => ApiClient(store: ref.watch(localStoreProvider)));
final trackingServiceProvider = Provider((ref) => TrackingService());

// ---------------------------------------------------------------------------
// Session (current user + partner)
// ---------------------------------------------------------------------------

/// `null` means signed out.
final sessionProvider = AsyncNotifierProvider<SessionNotifier, Session?>(SessionNotifier.new);

class SessionNotifier extends AsyncNotifier<Session?> {
  static Future<void>? _googleInit;

  ApiClient get _api => ref.read(apiClientProvider);
  LocalStore get _store => ref.read(localStoreProvider);

  @override
  Future<Session?> build() async {
    if (await _store.readToken() == null) return null;
    try {
      return await _api.me();
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        await _store.deleteToken();
        return null;
      }
      rethrow;
    }
  }

  Session? get _current => state.value;

  Future<void> _ensureGoogle() => _googleInit ??=
      GoogleSignIn.instance.initialize(serverClientId: AppConfig.googleServerClientId);

  /// Returns false when the user cancelled the Google dialog.
  Future<bool> signIn() async {
    debugPrint('Sign-in: initializing Google');
    await _ensureGoogle();
    final GoogleSignInAccount account;
    try {
      debugPrint('Sign-in: waiting for Google account picker');
      account = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (e) {
      debugPrint('Sign-in: Google failed (${e.code.name}): ${e.description}');
      if (e.code == GoogleSignInExceptionCode.canceled) return false;
      rethrow;
    }
    final idToken = account.authentication.idToken;
    debugPrint('Sign-in: got Google account ${account.email}, idToken ${idToken == null ? 'MISSING' : 'ok'}');
    if (idToken == null) throw const ApiException(0, 'invalid_google_token');

    debugPrint('Sign-in: exchanging token with backend');
    await _api.signInWithGoogle(idToken);
    debugPrint('Sign-in: loading /me');
    state = AsyncData(await _api.me());
    debugPrint('Sign-in: done');
    return true;
  }

  Future<void> signOut() async {
    await ref.read(trackingServiceProvider).stop();
    await _store.deleteToken();
    await _store.writeSharingPaused(false);
    try {
      await _ensureGoogle();
      await GoogleSignIn.instance.signOut();
    } catch (e) {
      debugPrint('Google sign-out failed: $e');
    }
    state = const AsyncData(null);
  }

  /// Re-fetches `/me` without showing a loading state; errors are ignored.
  Future<void> refresh() async {
    if (_current == null) return;
    try {
      state = AsyncData(await _api.me());
    } on ApiException catch (e) {
      if (e.isUnauthorized) await signOut();
    }
  }

  /// Full reload with loading state (used by the error screen's retry button).
  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }

  Future<Invite> createInvite() => _api.createInvite();

  Future<void> acceptInvite(String code) async {
    final payload = await _api.acceptInvite(code);
    final current = _current;
    if (current != null) state = AsyncData(current.paired(payload));
  }

  Future<void> unpair() async {
    await ref.read(trackingServiceProvider).stop();
    await _api.unpair();
    final current = _current;
    if (current != null) state = AsyncData(current.unpaired());
  }

  /// Saves the edited profile; [photo] is uploaded first so a failed name change keeps the new photo.
  Future<void> saveProfile({String? name, ({Uint8List bytes, String mimeType})? photo, bool removePhoto = false}) async {
    if (photo != null) {
      _applyUser(await _api.uploadPhoto(photo.bytes, photo.mimeType));
    } else if (removePhoto) {
      _applyUser(await _api.deletePhoto());
    }
    if (name != null) _applyUser(await _api.updateName(name));
  }

  void _applyUser(AppUser user) {
    final current = _current;
    if (current != null) state = AsyncData(current.withUser(user));
  }

  void handleRealtime(String event, Map<String, dynamic> data) {
    final current = _current;
    if (current == null) return;
    switch (event) {
      case 'status-updated':
        final status = DeviceStatus.fromJson(data);
        if (status.userId == current.partner?.id) {
          state = AsyncData(current.withPartnerStatus(status));
        }
      case 'profile-updated':
        final user = AppUser.fromJson(data['user'] as Map<String, dynamic>);
        if (user.id == current.partner?.id) {
          state = AsyncData(current.withPartner(user));
        } else if (user.id == current.user.id) {
          state = AsyncData(current.withUser(user));
        }
      case 'couple-paired':
        state = AsyncData(current.paired(data));
      case 'couple-unpaired':
        if (current.isPaired) {
          unawaited(ref.read(trackingServiceProvider).stop());
          state = AsyncData(current.unpaired());
        }
    }
  }
}

// ---------------------------------------------------------------------------
// Realtime + tracking side effects (watched by the root widget)
// ---------------------------------------------------------------------------

final realtimeServiceProvider = Provider((ref) {
  return RealtimeService(
    api: ref.watch(apiClientProvider),
    onEvent: (event, data) => ref.read(sessionProvider.notifier).handleRealtime(event, data),
    onReconnected: () => ref.read(sessionProvider.notifier).refresh(),
  );
});

/// Keeps Pusher subscriptions in line with the signed-in user and couple.
final realtimeSyncProvider = Provider<void>((ref) {
  final ids = ref.watch(sessionProvider.select((s) => (s.value?.user.id, s.value?.couple?.id)));
  ref.watch(realtimeServiceProvider).sync(userId: ids.$1, coupleId: ids.$2);
});

/// Starts the background service while paired and location is allowed; stops it otherwise.
final trackingSyncProvider = Provider<void>((ref) {
  final paired = ref.watch(sessionProvider.select((s) => s.hasValue ? (s.value?.isPaired ?? false) : null));
  final locationGranted =
      ref.watch(permissionsProvider.select((p) => p.hasValue ? p.value!.locationGranted : null));
  if (paired == null || locationGranted == null) return; // still loading: don't touch the service

  final tracking = ref.watch(trackingServiceProvider);
  unawaited(paired && locationGranted ? tracking.start() : tracking.stop());
});

/// Our own live status as produced by the background service.
final myLiveStatusProvider = StreamProvider<DeviceStatus>((ref) {
  return ref.watch(trackingServiceProvider).updates;
});

// ---------------------------------------------------------------------------
// Sharing pause
// ---------------------------------------------------------------------------

final sharingPausedProvider = AsyncNotifierProvider<SharingPausedNotifier, bool>(SharingPausedNotifier.new);

class SharingPausedNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() => ref.read(localStoreProvider).readSharingPaused();

  Future<void> set(bool paused) async {
    state = AsyncData(paused);
    await ref.read(localStoreProvider).writeSharingPaused(paused);
    ref.read(trackingServiceProvider).setPaused(paused);
  }
}

// ---------------------------------------------------------------------------
// Permissions
// ---------------------------------------------------------------------------

class PermissionsState {
  const PermissionsState({
    required this.locationServiceOn,
    required this.locationGranted,
    required this.backgroundLocationGranted,
    required this.notificationsGranted,
    required this.batteryOptimizationIgnored,
    required this.phoneGranted,
  });

  final bool locationServiceOn;
  final bool locationGranted;
  final bool backgroundLocationGranted;
  final bool notificationsGranted;
  final bool batteryOptimizationIgnored;

  /// Optional: only needed to show 4G/5G.
  final bool phoneGranted;

  bool get allRequiredGranted =>
      locationServiceOn &&
      locationGranted &&
      backgroundLocationGranted &&
      notificationsGranted &&
      batteryOptimizationIgnored;
}

final permissionsProvider =
    AsyncNotifierProvider<PermissionsNotifier, PermissionsState>(PermissionsNotifier.new);

class PermissionsNotifier extends AsyncNotifier<PermissionsState> {
  @override
  Future<PermissionsState> build() => _check();

  Future<PermissionsState> _check() async => PermissionsState(
        locationServiceOn: await Geolocator.isLocationServiceEnabled(),
        locationGranted: await Permission.locationWhenInUse.isGranted,
        backgroundLocationGranted: await Permission.locationAlways.isGranted,
        notificationsGranted: await Permission.notification.isGranted,
        batteryOptimizationIgnored: await Permission.ignoreBatteryOptimizations.isGranted,
        phoneGranted: await Permission.phone.isGranted,
      );

  Future<void> recheck() async => state = AsyncData(await _check());

  /// Walks through the missing permissions one by one (Android requires
  /// foreground location before background location).
  Future<void> requestAll() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      await Geolocator.openLocationSettings();
      return recheck();
    }
    final location = await Permission.locationWhenInUse.request();
    if (location.isPermanentlyDenied) {
      await openAppSettings();
      return recheck();
    }
    if (location.isGranted) {
      await Permission.locationAlways.request();
    }
    await Permission.notification.request();
    await Permission.phone.request();
    await Permission.ignoreBatteryOptimizations.request();
    await recheck();
  }
}

// ---------------------------------------------------------------------------
// Invite deep links: lovetracking://invite?code=XXXXXX
// ---------------------------------------------------------------------------

/// Invite code received through a deep link that hasn't been handled yet.
final pendingInviteProvider = NotifierProvider<PendingInviteNotifier, String?>(PendingInviteNotifier.new);

class PendingInviteNotifier extends Notifier<String?> {
  @override
  String? build() {
    final sub = AppLinks().uriLinkStream.listen((uri) {
      final code = inviteCodeFromUri(uri);
      if (code != null) state = code;
    });
    ref.onDispose(sub.cancel);
    return null;
  }

  void clear() => state = null;
}

String? inviteCodeFromUri(Uri uri) {
  if (uri.scheme != AppConfig.inviteScheme || uri.host != AppConfig.inviteHost) return null;
  final code = uri.queryParameters['code']?.trim().toUpperCase();
  return code == null || code.isEmpty ? null : code;
}

// ---------------------------------------------------------------------------
// Partner address (reverse geocoding with Android's built-in Geocoder)
// ---------------------------------------------------------------------------

/// Coordinates are rounded to ~50 m so the address is looked up again only after a real move.
typedef AddressKey = ({double lat, double lng});

AddressKey addressKey(double lat, double lng) =>
    (lat: (lat * 2000).roundToDouble() / 2000, lng: (lng * 2000).roundToDouble() / 2000);

final addressProvider = FutureProvider.autoDispose.family<String?, AddressKey>(
  (ref, key) async {
    final marks = await Geocoding().placemarkFromCoordinates(key.lat, key.lng, locale: const Locale('id', 'ID'));
    if (marks.isEmpty) return null;
    final m = marks.first;
    return formatAddress(
      street: m.street ?? [m.thoroughfare, m.subThoroughfare].whereType<String>().join(' '),
      subLocality: m.subLocality,
      locality: m.locality,
      subAdministrativeArea: m.subAdministrativeArea,
      administrativeArea: m.administrativeArea,
      postalCode: m.postalCode,
    );
  },
  retry: (_, _) => null,
);

// ---------------------------------------------------------------------------
// Light / dark mode
// ---------------------------------------------------------------------------

ThemeMode themeModeFromName(String? name) =>
    ThemeMode.values.firstWhere((m) => m.name == name, orElse: () => ThemeMode.system);

/// The saved theme, read in `main()` before the first frame.
final initialThemeModeProvider = Provider<ThemeMode>((ref) => ThemeMode.system);

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ref.watch(initialThemeModeProvider);

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ref.read(localStoreProvider).writeThemeMode(mode.name);
  }
}
