import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:love_tracking/models/models.dart';
import 'package:love_tracking/providers.dart';
import 'package:love_tracking/services/device_snapshot.dart';
import 'package:love_tracking/ui/format.dart';

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

    test('speed hides when stationary', () {
      expect(formatSpeed(0.4), isNull);
      expect(formatSpeed(10), '36 km/j');
    });

    test('network label', () {
      final wifi = DeviceStatus(userId: 'u', networkType: 'wifi', carrier: 'XL', updatedAt: base.updatedAt);
      expect(networkLabel(wifi), 'Wi-Fi');
      expect(
        networkLabel(DeviceStatus(
          userId: 'u',
          networkType: 'mobile',
          carrier: 'Telkomsel',
          mobileNetworkGen: '5G',
          updatedAt: base.updatedAt,
        )),
        'Telkomsel 5G',
      );
      expect(
        networkLabel(DeviceStatus(userId: 'u', networkType: 'mobile', updatedAt: base.updatedAt)),
        'Data seluler',
      );
    });

    test('battery label', () {
      expect(
        batteryLabel(DeviceStatus(userId: 'u', battery: 76, batteryState: 'charging', updatedAt: base.updatedAt)),
        '76% · mengisi',
      );
    });
  });
}
