import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../models/models.dart';
import '../providers.dart';
import 'format.dart';
import 'profile_screen.dart';
import 'theme.dart';
import 'user_pin.dart';
import 'widgets.dart';

/// Partner data older than this is shown as "last seen".
const _staleAfter = Duration(minutes: 15);
const _defaultCenter = LatLng(-2.5, 118); // Indonesia

LatLng? _latLng(DeviceStatus? s) => s != null && s.hasLocation ? LatLng(s.lat!, s.lng!) : null;

/// Frames "6A"–"6I" (map), "7 – Menu", "8 – Dialog Putuskan".
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _map = MapController();
  bool _mapReady = false;
  bool _centeredOnce = false;

  void _centerOn(LatLng point, {double zoom = 16}) {
    if (_mapReady) _map.move(point, zoom);
  }

  void _fitBoth(LatLng a, LatLng b) {
    if (!_mapReady) return;
    _map.fitCamera(CameraFit.coordinates(
      coordinates: [a, b],
      padding: const EdgeInsets.fromLTRB(64, 160, 64, 280),
      maxZoom: 17,
    ));
  }

  /// Centers on the partner the first time we learn where they are.
  void _maybeCenterInitially(LatLng? partner, LatLng? me) {
    if (_centeredOnce || !_mapReady) return;
    final target = partner ?? me;
    if (target == null) return;
    _centeredOnce = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (partner != null && me != null) {
        _fitBoth(partner, me);
      } else {
        _centerOn(target);
      }
    });
  }

  Future<void> _confirmUnpair(String partnerName) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Putuskan pasangan?'),
        content: Text('Kamu dan $partnerName tidak akan bisa saling melihat lokasi lagi. '
            'Kalian perlu kode undangan baru untuk terhubung kembali.'),
        actionsAlignment: MainAxisAlignment.start,
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              shape: const StadiumBorder(),
              textStyle: const TextStyle(fontFamily: 'Roboto', fontSize: 14, fontWeight: FontWeight.w600),
            ),
            child: const Text('Putuskan'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(sessionProvider.notifier).unpair();
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider).value;
    if (session == null || !session.isPaired) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final partner = session.partner!;
    final partnerStatus = session.partnerStatus;
    final myStatus = ref.watch(myLiveStatusProvider).value ?? session.myStatus;
    final paused = ref.watch(sharingPausedProvider).value ?? false;
    final permissions = ref.watch(permissionsProvider).value;

    final partnerPoint = _latLng(partnerStatus);
    final myPoint = paused ? null : _latLng(myStatus);
    final partnerStale =
        partnerStatus == null || DateTime.now().difference(partnerStatus.updatedAt) > _staleAfter;
    _maybeCenterInitially(partnerPoint, myPoint);

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: partnerPoint ?? myPoint ?? _defaultCenter,
              initialZoom: (partnerPoint ?? myPoint) != null ? 15 : 4.5,
              backgroundColor: dark ? const Color(0xFF1E1E1E) : const Color(0xFFE9E4DA),
              onMapReady: () {
                _mapReady = true;
                _maybeCenterInitially(partnerPoint, myPoint);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.lovetracking.love_tracking',
                tileBuilder: dark ? darkModeTileBuilder : null,
              ),
              if (partnerPoint != null && (partnerStatus!.accuracy ?? 0) > 0)
                CircleLayer(circles: [
                  CircleMarker(
                    point: partnerPoint,
                    radius: partnerStatus.accuracy!,
                    useRadiusInMeter: true,
                    color: AppColors.love.withValues(alpha: 0.12),
                    borderColor: AppColors.love.withValues(alpha: 0.4),
                    borderStrokeWidth: 1,
                  ),
                ]),
              if (partnerPoint != null && myPoint != null)
                PolylineLayer(polylines: [
                  Polyline(
                    points: [myPoint, partnerPoint],
                    color: AppColors.love.withValues(alpha: 0.5),
                    strokeWidth: 2,
                  ),
                ]),
              MarkerLayer(markers: [
                if (myPoint != null)
                  Marker(
                    point: myPoint,
                    width: userPinSize(40).width,
                    height: userPinSize(40).height,
                    alignment: Alignment.topCenter,
                    child: UserPin(
                      user: session.user,
                      color: AppColors.me,
                      avatarSize: 40,
                      movement: movementOf(myStatus),
                    ),
                  ),
                if (partnerPoint != null)
                  Marker(
                    point: partnerPoint,
                    width: userPinSize(48).width,
                    height: userPinSize(48).height,
                    alignment: Alignment.topCenter,
                    child: UserPin(
                      user: partner,
                      color: partnerStale ? AppColors.stale : AppColors.love,
                      avatarSize: 48,
                      movement: movementOf(partnerStatus, stale: partnerStale),
                      faded: partnerStale,
                    ),
                  ),
              ]),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TopBar(
                    partner: partner,
                    paused: paused,
                    onProfile: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(builder: (_) => const ProfileScreen()),
                    ),
                    onTogglePause: () => ref.read(sharingPausedProvider.notifier).set(!paused),
                    onUnpair: () => _confirmUnpair(partner.firstName),
                    onSignOut: () => ref.read(sessionProvider.notifier).signOut(),
                  ),
                  if (permissions != null && !permissions.allRequiredGranted) ...[
                    const SizedBox(height: 8),
                    _PermissionBanner(state: permissions),
                  ],
                  if (paused) ...[
                    const SizedBox(height: 8),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: _InfoChip(icon: Symbols.pause_circle_rounded, text: 'Berbagi lokasimu sedang dijeda'),
                    ),
                  ],
                  const Spacer(),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Column(spacing: 8, children: [
                      if (partnerPoint != null && myPoint != null)
                        _MapButton(
                          icon: Symbols.zoom_out_map_rounded,
                          tooltip: 'Lihat berdua',
                          onPressed: () => _fitBoth(partnerPoint, myPoint),
                        ),
                      if (myPoint != null)
                        _MapButton(
                          icon: Symbols.my_location_rounded,
                          tooltip: 'Lokasiku',
                          onPressed: () => _centerOn(myPoint),
                        ),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  _PartnerCard(
                    partner: partner,
                    status: partnerStatus,
                    myPoint: myPoint,
                    onTap: partnerPoint == null ? null : () => _centerOn(partnerPoint),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '© OpenStreetMap contributors',
                    style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rounded "floating" container used by every overlay card on the map.
class _FloatingCard extends StatelessWidget {
  const _FloatingCard({required this.child, this.padding = const EdgeInsets.all(12), this.onTap});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), boxShadow: floatingShadow),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
      ),
    );
  }
}

enum _MenuAction { profile, togglePause, unpair, signOut }

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.partner,
    required this.paused,
    required this.onProfile,
    required this.onTogglePause,
    required this.onUnpair,
    required this.onSignOut,
  });

  final AppUser partner;
  final bool paused;
  final VoidCallback onProfile;
  final VoidCallback onTogglePause;
  final VoidCallback onUnpair;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    PopupMenuItem<_MenuAction> item(_MenuAction value, IconData icon, String label) => PopupMenuItem(
          value: value,
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            Icon(icon, size: 22, color: scheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Text(label),
          ]),
        );

    return _FloatingCard(
      padding: const EdgeInsets.only(left: 16, right: 4),
      child: Row(children: [
        const Icon(Symbols.favorite_rounded, size: 22, color: AppColors.love),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Kamu & ${partner.firstName}',
            style: displayText(16, color: scheme.onSurface),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        PopupMenuButton<_MenuAction>(
          icon: Icon(Symbols.more_vert_rounded, size: 24, color: scheme.onSurfaceVariant),
          position: PopupMenuPosition.under,
          menuPadding: const EdgeInsets.all(8),
          onSelected: (action) => switch (action) {
            _MenuAction.profile => onProfile(),
            _MenuAction.togglePause => onTogglePause(),
            _MenuAction.unpair => onUnpair(),
            _MenuAction.signOut => onSignOut(),
          },
          itemBuilder: (context) => [
            item(_MenuAction.profile, Symbols.account_circle_rounded, 'Profil'),
            paused
                ? item(_MenuAction.togglePause, Symbols.play_circle_rounded, 'Lanjutkan berbagi lokasi')
                : item(_MenuAction.togglePause, Symbols.pause_circle_rounded, 'Jeda berbagi lokasi'),
            item(_MenuAction.unpair, Symbols.heart_broken_rounded, 'Putuskan pasangan'),
            item(_MenuAction.signOut, Symbols.logout_rounded, 'Keluar'),
          ],
        ),
      ]),
    );
  }
}

class _PermissionBanner extends ConsumerWidget {
  const _PermissionBanner({required this.state});

  final PermissionsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final missing = [
      if (!state.locationServiceOn) 'GPS mati',
      if (!state.locationGranted) 'izin lokasi',
      if (state.locationGranted && !state.backgroundLocationGranted) 'lokasi "Izinkan sepanjang waktu"',
      if (!state.notificationsGranted) 'notifikasi',
      if (!state.batteryOptimizationIgnored) 'pengecualian penghemat baterai',
    ];
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 4),
      decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Text(
            'Agar lokasimu tetap terkirim saat HP terkunci, aktifkan: ${missing.join(', ')}.',
            style: TextStyle(fontSize: 13, color: scheme.onErrorContainer),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => ref.read(permissionsProvider.notifier).requestAll(),
            child: const Text('Izinkan'),
          ),
        ),
      ]),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 18, color: scheme.onSurface),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(fontSize: 13, color: scheme.onSurface)),
      ]),
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: DecoratedBox(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), boxShadow: floatingShadow),
        child: Material(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox.square(dimension: 40, child: Icon(icon, size: 18, color: scheme.onSurface)),
          ),
        ),
      ),
    );
  }
}

class _PartnerCard extends ConsumerStatefulWidget {
  const _PartnerCard({required this.partner, required this.status, required this.myPoint, this.onTap});

  final AppUser partner;
  final DeviceStatus? status;
  final LatLng? myPoint;
  final VoidCallback? onTap;

  @override
  ConsumerState<_PartnerCard> createState() => _PartnerCardState();
}

class _PartnerCardState extends ConsumerState<_PartnerCard> {
  late final Timer _ticker;

  @override
  void initState() {
    super.initState();
    // Keeps "x menit lalu" current.
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = widget.status;
    final partnerPoint = _latLng(s);

    final String subtitle;
    if (s == null) {
      subtitle = 'Menunggu data pertama dari ${widget.partner.firstName}…';
    } else if (s.sharingPaused) {
      subtitle = 'Berbagi lokasi dijeda · ${timeAgo(s.updatedAt)}';
    } else if (DateTime.now().difference(s.updatedAt) > _staleAfter) {
      subtitle = 'Terakhir aktif ${timeAgo(s.updatedAt)}';
    } else {
      subtitle = 'Diperbarui ${timeAgo(s.updatedAt)}';
    }

    final distance = partnerPoint != null && widget.myPoint != null
        ? const Distance().as(LengthUnit.Meter, widget.myPoint!, partnerPoint)
        : null;
    final address = partnerPoint == null
        ? null
        : ref.watch(addressProvider(addressKey(partnerPoint.latitude, partnerPoint.longitude)));

    return _FloatingCard(
      onTap: widget.onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 10, children: [
        Row(children: [
          UserAvatar(user: widget.partner, size: 40, fontSize: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 2, children: [
              Text(
                widget.partner.name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: scheme.onSurface),
              ),
              Text(subtitle, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            ]),
          ),
          if (widget.onTap != null) const Icon(Symbols.center_focus_strong_rounded, size: 24, color: AppColors.love),
        ]),
        if (address != null && !(address.hasError && !address.hasValue) && !(address.hasValue && address.value == null))
          _AddressRow(text: address.value ?? 'Mencari alamat…', loading: !address.hasValue),
        if (s != null)
          Wrap(spacing: 6, runSpacing: 6, children: [
            _StatChip(icon: batteryIcon(s), iconColor: batteryColor(s, scheme), label: batteryLabel(s)),
            _StatChip(icon: networkIcon(s), label: networkLabel(s)),
            if (s.networkType == 'wifi' && s.carrier != null)
              _StatChip(icon: Symbols.sim_card_rounded, label: s.carrier!),
            if (distance != null) _StatChip(icon: Symbols.straighten_rounded, label: formatDistance(distance)),
          ]),
      ]),
    );
  }
}

class _AddressRow extends StatelessWidget {
  const _AddressRow({required this.text, required this.loading});

  final String text;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(
        padding: EdgeInsets.only(top: 1),
        child: Icon(Symbols.location_on_rounded, size: 18, color: AppColors.love),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            height: 1.35,
            color: loading ? scheme.onSurfaceVariant : scheme.onSurface,
          ),
        ),
      ),
    ]);
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label, this.iconColor});

  final IconData icon;
  final String label;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 18, color: iconColor ?? scheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 13, color: scheme.onSurface)),
      ]),
    );
  }
}
