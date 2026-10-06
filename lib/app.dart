import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'config.dart';
import 'providers.dart';
import 'ui/home_screen.dart';
import 'ui/login_screen.dart';
import 'ui/pairing_screen.dart';
import 'ui/theme.dart';

class LoveTrackingApp extends StatelessWidget {
  const LoveTrackingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Love Tracking',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: AppConfig.missingKeys.isEmpty ? const _Root() : const _MissingConfigScreen(),
    );
  }
}

/// Chooses the screen from the session state and hosts app-wide side effects.
class _Root extends ConsumerStatefulWidget {
  const _Root();

  @override
  ConsumerState<_Root> createState() => _RootState();
}

class _RootState extends ConsumerState<_Root> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: () {
      // Permissions may have been changed in system settings; partner data may be stale.
      ref.read(permissionsProvider.notifier).recheck();
      ref.read(sessionProvider.notifier).refresh();
      ref.read(trackingServiceProvider).flush();
    });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(realtimeSyncProvider);
    ref.watch(trackingSyncProvider);
    ref.watch(pendingInviteProvider); // start listening for invite links immediately

    // Ask for permissions as soon as the couple is formed.
    ref.listen(sessionProvider.select((s) => s.value?.isPaired ?? false), (was, isPaired) {
      if (isPaired && was == false) ref.read(permissionsProvider.notifier).requestAll();
    });
    ref.listen(pendingInviteProvider, (_, code) {
      if (code != null && (ref.read(sessionProvider).value?.isPaired ?? false)) {
        ref.read(pendingInviteProvider.notifier).clear();
        showSnack(context, 'Kamu sudah terhubung dengan pasangan. Putuskan dulu untuk memakai undangan baru.');
      }
    });

    final session = ref.watch(sessionProvider);
    return switch (session) {
      AsyncData(value: null) => const LoginScreen(),
      AsyncData(:final value?) when !value.isPaired => const PairingScreen(),
      AsyncData() => const HomeScreen(),
      AsyncError(:final error) => _ErrorScreen(error: error),
      _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
    };
  }
}

class _ErrorScreen extends ConsumerWidget {
  const _ErrorScreen({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Icon(Symbols.cloud_off_rounded, size: 64, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              errorMessage(error),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: scheme.onSurface),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => ref.read(sessionProvider.notifier).reload(),
              icon: const Icon(Symbols.refresh_rounded),
              label: const Text('Coba lagi'),
            ),
          ]),
        ),
      ),
    );
  }
}

class _MissingConfigScreen extends StatelessWidget {
  const _MissingConfigScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Konfigurasi belum lengkap: ${AppConfig.missingKeys.join(', ')}.\n\n'
            'Jalankan dengan:\nflutter run --dart-define-from-file=config/dev.json',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
