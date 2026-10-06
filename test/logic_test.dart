import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:love_tracking/models/models.dart';
import 'package:love_tracking/providers.dart';
import 'package:love_tracking/services/device_snapshot.dart';
import 'package:love_tracking/ui/format.dart';
import 'package:love_tracking/ui/movement.dart';

void main() {
  group('inviteCodeFromUri', () {
    test('reads and normalizes the code', () {
      expect(inviteCodeFromUri(Uri.parse('lovetracking://invite?code=k7p2qx')), 'K7P2QX');
    });

    test('ignores other links', () {
      expect(inviteCodeFromUri(Uri.parse('https://example.com/invite?code=K7P2QX')), isNull);
      expect(inviteCodeFromUri(Uri.parse('lovetracking://other?code=K7P2QX')), isNull);
      expect(inviteCodeFromUri(Uri.parse('lovetracking://invite')), isNull);
    });
  });

  group('DeviceSnapshot.networkTypeOf', () {
    test('prefers wifi over mobile and vpn', () {
      expect(
        DeviceSnapshot.networkTypeOf([ConnectivityResult.vpn, ConnectivityResult.mobile, ConnectivityResult.wifi]),
        'wifi',
      );
      expect(DeviceSnapshot.networkTypeOf([ConnectivityResult.vpn, ConnectivityResult.mobile]), 'mobile');
    });

    test('reports none when offline', () {
      expect(DeviceSnapshot.networkTypeOf([]), 'none');
      expect(DeviceSnapshot.networkTypeOf([ConnectivityResult.none]), 'none');
    });
  });

  group('Session', () {
    final me = {
      'user': {'id': 'u1', 'email': 'a@x.com', 'name': 'Ana Putri', 'photoUrl': null},
      'couple': null,
      'partner': null,
      'partnerStatus': null,
      'myStatus': null,
    };
    final pairedPayload = {
      'couple': {'id': 'c1', 'createdAt': '2026-10-06T05:00:00.000Z'},
      'partner': {'id': 'u2', 'email': 'b@x.com', 'name': 'Budi', 'photoUrl': null},
      'partnerStatus': {
        'userId': 'u2',
        'lat': -6.2,
        'lng': 106,
        'battery': 76,
        'batteryState': 'charging',
        'networkType': 'mobile',
        'carrier': 'Telkomsel',
        'mobileNetworkGen': '4G',
        'sharingPaused': false,
        'updatedAt': '2026-10-06T05:00:00.000Z',
      },
    };

    test('parses /me and pairing payloads', () {
      final session = Session.fromMeJson(me);
      expect(session.isPaired, isFalse);
      expect(session.user.firstName, 'Ana');

      final paired = session.paired(pairedPayload);
      expect(paired.isPaired, isTrue);
      expect(paired.partnerStatus!.lng, 106.0); // ints become doubles
      expect(paired.partnerStatus!.hasLocation, isTrue);
      expect(paired.unpaired().isPaired, isFalse);
    });

    test('paused status has no location', () {
      final status = DeviceStatus.fromJson({
        ...pairedPayload['partnerStatus']!,
        'sharingPaused': true,
      });
      expect(status.hasLocation, isFalse);
    });
  });

  group('format', () {
    final base = DeviceStatus(userId: 'u', updatedAt: DateTime.now());

    test('distance', () {
      expect(formatDistance(420.4), '420 m');
      expect(formatDistance(3240), '3,2 km');
      expect(formatDistance(25400), '25 km');
    });

    test('movement thresholds', () {
      expect(movementForSpeed(0.3), isNull);
      expect(movementForSpeed(1.4), Movement.walking);
      expect(movementForSpeed(3), Movement.running);
      expect(movementForSpeed(12), Movement.traveling);
    });

    test('battery label', () {
      expect(
        batteryLabel(DeviceStatus(userId: 'u', battery: 76, batteryState: 'charging', updatedAt: base.updatedAt)),
        '76% · mengisi',
      );
    });
  });

  group('profile & address', () {
    test('formatAddress builds an Indonesian address without repeats', () {
      expect(
        formatAddress(
          street: 'Jl. Jend. Sudirman Kav. 52-53',
          subLocality: 'Senayan',
          locality: 'Kebayoran Baru',
          subAdministrativeArea: 'Kota Jakarta Selatan',
          administrativeArea: 'Daerah Khusus Ibukota Jakarta',
          postalCode: '12190',
        ),
        'Jl. Jend. Sudirman Kav. 52-53, Senayan, Kebayoran Baru, Kota Jakarta Selatan, '
        'Daerah Khusus Ibukota Jakarta 12190',
      );
      expect(
        formatAddress(street: '8Q7X+2F', subLocality: 'Senayan', locality: 'Senayan', administrativeArea: ''),
        'Senayan',
      );
      expect(formatAddress(), isNull);
    });

    test('addressKey rounds to ~50 m', () {
      expect(addressKey(-6.20860, 106.84500), addressKey(-6.20840, 106.84520));
      expect(addressKey(-6.2088, 106.8456) == addressKey(-6.2100, 106.8456), isFalse);
    });

    test('hasCustomPhoto only for photos served by our backend', () {
      const google = AppUser(id: 'u1', email: 'a', name: 'A', photoUrl: 'https://lh3.googleusercontent.com/a/x');
      const custom = AppUser(id: 'u1', email: 'a', name: 'A', photoUrl: 'https://api.example/users/u1/photo?v=1');
      expect(google.hasCustomPhoto, isFalse);
      expect(custom.hasCustomPhoto, isTrue);
    });
  });

  group('MovementEstimator', () {
    final t0 = DateTime(2026, 10, 6, 12);
    const lat0 = -6.2;
    const lng0 = 106.8;
    const degPerMeter = 1 / 111320;

    /// Feeds samples every 10 s; [northMeters] gives each sample's offset from the start.
    Movement? feed(List<double> northMeters, {double accuracy = 10, double reportedSpeed = 0, List<double>? eastMeters}) {
      var now = t0;
      final e = MovementEstimator(clock: () => now);
      Movement? m;
      for (var i = 0; i < northMeters.length; i++) {
        now = t0.add(Duration(seconds: i * 10));
        m = e.update(DeviceStatus(
          userId: 'u',
          lat: lat0 + northMeters[i] * degPerMeter,
          lng: lng0 + (eastMeters?[i] ?? 0) * degPerMeter,
          accuracy: accuracy,
          speed: reportedSpeed,
          updatedAt: now,
        ));
      }
      return m;
    }

    test('sitting indoors: GPS jumps 30-45 m with a fake 2 m/s speed is not movement', () {
      expect(
        feed([0, 33, -12, 28, 5, 40, -8], eastMeters: [0, 11, 28, -10, 33, 0, 20], accuracy: 25, reportedSpeed: 2),
        isNull,
      );
    });

    test('old app version repeating one position with a stale speed is not movement', () {
      expect(feed([0, 0, 0, 0, 0, 0], reportedSpeed: 1.6), isNull);
    });

    test('walking ~1.4 m/s', () {
      expect(feed([0, 14, 28, 42, 56, 70, 84]), Movement.walking);
    });

    test('riding a motorbike ~12 m/s', () {
      expect(feed([0, 120, 240, 360]), Movement.traveling);
    });

    test('needs at least 20 s of data before deciding', () {
      expect(feed([0, 120]), isNull);
    });

    test('stops showing movement after standing still for a minute', () {
      // Walked for 30 s, then stood still for 70 s.
      expect(feed([0, 14, 28, 42, 42, 42, 42, 42, 42, 42, 42]), isNull);
    });
  });
}
