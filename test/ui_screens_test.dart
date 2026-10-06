// Renders every screen state from the Pendev mockup and fails on layout errors (overflow etc.).
//
// Visual previews: UI_PREVIEW=1 flutter test --update-goldens test/ui_screens_test.dart
// writes PNGs to test/preview/ (git-ignored) for side-by-side comparison with the mockup.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:love_tracking/models/models.dart';
import 'package:love_tracking/providers.dart';
import 'package:love_tracking/ui/home_screen.dart';
import 'package:love_tracking/ui/login_screen.dart';
import 'package:love_tracking/ui/pairing_screen.dart';
import 'package:love_tracking/ui/profile_screen.dart';
import 'package:love_tracking/ui/theme.dart';

final _preview = Platform.environment['UI_PREVIEW'] == '1';

class _FakeSession extends SessionNotifier {
  _FakeSession(this.initial);
  final Session? initial;

  @override
  Future<Session?> build() async => initial;

  @override
  Future<Invite> createInvite() async => Invite(
        code: 'K7P2QX',
        expiresAt: DateTime(2026, 10, 7, 14, 30),
        link: 'lovetracking://invite?code=K7P2QX',
      );
}

class _FakePermissions extends PermissionsNotifier {
  _FakePermissions(this.value);
  final PermissionsState value;

  @override
  Future<PermissionsState> build() async => value;
}

class _FakePaused extends SharingPausedNotifier {
  _FakePaused(this.value);
  final bool value;

  @override
  Future<bool> build() async => value;
}

class _FakeInvite extends PendingInviteNotifier {
  _FakeInvite(this.code);
  final String? code;

  @override
  String? build() => code;
}

const _ana = AppUser(id: 'u1', email: 'ana@gmail.com', name: 'Ana Putri');
const _budi = AppUser(id: 'u2', email: 'budi@gmail.com', name: 'Budi Santoso');

PermissionsState _perms({bool all = true}) => PermissionsState(
      locationServiceOn: true,
      locationGranted: true,
      backgroundLocationGranted: all,
      notificationsGranted: true,
      batteryOptimizationIgnored: all,
      phoneGranted: true,
    );

DeviceStatus _status({
  String userId = 'u2',
  double? lat = -6.2088,
  double? lng = 106.8456,
  double? speed = 10,
  int battery = 76,
  String batteryState = 'charging',
  String networkType = 'mobile',
  String? carrier = 'Telkomsel',
  String? gen = '4G',
  bool paused = false,
  Duration age = Duration.zero,
}) =>
    DeviceStatus(
      userId: userId,
      lat: paused ? null : lat,
      lng: paused ? null : lng,
      accuracy: 40,
      speed: speed,
      battery: battery,
      batteryState: batteryState,
      networkType: networkType,
      carrier: carrier,
      mobileNetworkGen: gen,
      sharingPaused: paused,
      updatedAt: DateTime.now().subtract(age),
    );

Session _paired({DeviceStatus? partner, DeviceStatus? me}) => Session(
      user: _ana,
      couple: Couple(id: 'c1', createdAt: DateTime(2026, 10, 6)),
      partner: _budi,
      partnerStatus: partner,
      myStatus: me ?? _status(userId: 'u1', lat: -6.2300, lng: 106.8700, speed: 0),
    );

Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      loader.addFont(File(f).readAsBytes().then((b) => ByteData.view(b.buffer)));
    }
    await loader.load();
  }

  final flutterRoot = File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.parent.path;
  final roboto = '$flutterRoot/bin/cache/artifacts/material_fonts';
  await load('Roboto', ['$roboto/roboto-regular.ttf', '$roboto/roboto-medium.ttf', '$roboto/roboto-bold.ttf']);
  await load('Poppins', ['assets/fonts/Poppins-SemiBold.ttf', 'assets/fonts/Poppins-Bold.ttf']);

  final config = File('.dart_tool/package_config.json').readAsStringSync();
  final symbolsRoot = RegExp(r'"rootUri":\s*"file:///([^"]*material_symbols_icons[^"]*)"').firstMatch(config)!.group(1)!;
  await load('packages/material_symbols_icons/MaterialSymbolsRounded', ['$symbolsRoot/lib/fonts/MaterialSymbolsRounded.ttf']);
}

Future<void> _render(
  WidgetTester tester,
  String name,
  Widget screen, {
  Session? session,
  bool paused = false,
  PermissionsState? permissions,
  String? pendingInvite,
  Brightness brightness = Brightness.light,
  Future<void> Function(WidgetTester tester)? interact,
}) async {
  tester.view
    ..physicalSize = const Size(360 * 3, 800 * 3)
    ..devicePixelRatio = 3
    ..padding = const FakeViewPadding(top: 40 * 3, bottom: 16 * 3);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(ProviderScope(
    overrides: [
      sessionProvider.overrideWith(() => _FakeSession(session)),
      permissionsProvider.overrideWith(() => _FakePermissions(permissions ?? _perms())),
      sharingPausedProvider.overrideWith(() => _FakePaused(paused)),
      pendingInviteProvider.overrideWith(() => _FakeInvite(pendingInvite)),
      myLiveStatusProvider.overrideWith((ref) => const Stream.empty()),
      addressProvider.overrideWith((ref, key) async =>
          'Jl. Jend. Sudirman Kav. 52-53, Senayan, Kebayoran Baru, Kota Jakarta Selatan, DKI Jakarta 12190'),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(brightness),
      home: screen,
    ),
  ));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
  if (interact != null) await interact(tester);

  expect(tester.takeException(), isNull);
  if (_preview) {
    await _precacheImages(tester);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('preview/$name.png'));
  }

  await tester.pumpWidget(const SizedBox()); // dispose timers
}

/// `Image.asset` decodes through real file I/O, which `flutter_test`'s fake async
/// zone never completes — so goldens would capture the image blank. Resolve every
/// asset image inside `runAsync` first, then repaint.
Future<void> _precacheImages(WidgetTester tester) async {
  final assets = <String>{};
  for (final widget in find.byType(Image).evaluate()) {
    final provider = (widget.widget as Image).image;
    if (provider is AssetImage) assets.add(provider.assetName);
  }
  if (assets.isEmpty) return;

  final context = tester.element(find.byType(MaterialApp));
  await tester.runAsync(() async {
    for (final asset in assets) {
      await precacheImage(AssetImage(asset), context);
    }
  });
  await tester.pump();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // flutter_map's tile cache asks path_provider for a directory.
    final cacheDir = Directory.systemTemp.createTempSync('tiles').path;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => cacheDir,
    );
    await _loadFonts();
  });

  testWidgets('1 Login', (t) => _render(t, '1-login', const LoginScreen()));
  testWidgets('1B Login with pending invite',
      (t) => _render(t, '1B-login-invite', const LoginScreen(), pendingInvite: 'K7P2QX'));

  testWidgets('2 Pairing', (t) => _render(t, '2-pairing', const PairingScreen(), session: const Session(user: _ana)));
  testWidgets(
    '3 Pairing with code',
    (t) => _render(t, '3-pairing-code', const PairingScreen(), session: const Session(user: _ana),
        interact: (t) async {
      await t.tap(find.text('Buat kode undangan'));
      await t.pump(const Duration(milliseconds: 100));
    }),
  );

  final home = <String, ({Session session, bool paused, PermissionsState? perms, Brightness b})>{
    '6A-normal': (session: _paired(partner: _status()), paused: false, perms: null, b: Brightness.light),
    '6B-wifi': (
      session: _paired(
          partner: _status(speed: 0, battery: 54, batteryState: 'discharging', networkType: 'wifi', carrier: 'Indosat', age: const Duration(minutes: 2))),
      paused: false,
      perms: null,
      b: Brightness.light,
    ),
    '6C-low-battery': (session: _paired(partner: _status(battery: 12, batteryState: 'discharging', speed: 0)), paused: false, perms: null, b: Brightness.light),
    '6D-partner-paused': (
      session: _paired(partner: _status(paused: true, battery: 64, batteryState: 'discharging', networkType: 'wifi', carrier: null, age: const Duration(minutes: 5))),
      paused: false,
      perms: null,
      b: Brightness.light,
    ),
    '6E-stale': (
      session: _paired(partner: _status(battery: 41, batteryState: 'discharging', networkType: 'none', speed: 0, age: const Duration(hours: 2))),
      paused: false,
      perms: null,
      b: Brightness.light,
    ),
    '6F-waiting': (session: _paired(), paused: false, perms: null, b: Brightness.light),
    '6G-me-paused': (session: _paired(partner: _status()), paused: true, perms: null, b: Brightness.light),
    '6H-permissions': (session: _paired(partner: _status()), paused: false, perms: _perms(all: false), b: Brightness.light),
    '6I-dark': (session: _paired(partner: _status()), paused: false, perms: null, b: Brightness.dark),
  };
  for (final MapEntry(key: name, value: v) in home.entries) {
    testWidgets('$name home', (t) => _render(t, name, const HomeScreen(),
        session: v.session, paused: v.paused, permissions: v.perms, brightness: v.b));
  }

  testWidgets('11 Profile', (t) => _render(t, '11-profile', const ProfileScreen(), session: _paired(partner: _status())));

  testWidgets(
    '7 Menu',
    (t) => _render(t, '7-menu', const HomeScreen(), session: _paired(partner: _status()), interact: (t) async {
      await t.tap(find.byTooltip('Show menu'));
      await t.pumpAndSettle();
    }),
  );
  testWidgets(
    '8 Unpair dialog',
    (t) => _render(t, '8-dialog', const HomeScreen(), session: _paired(partner: _status()), interact: (t) async {
      await t.tap(find.byTooltip('Show menu'));
      await t.pumpAndSettle();
      await t.tap(find.text('Putuskan pasangan'));
      await t.pumpAndSettle();
    }),
  );
}
