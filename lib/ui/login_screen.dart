import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../providers.dart';
import 'theme.dart';

/// Frames "1 – Login", "1B – Login Undangan Tertunda", "1C – Login Loading".
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _busy = false;

  Future<void> _signIn() async {
    setState(() => _busy = true);
    try {
      await ref.read(sessionProvider.notifier).signIn();
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasPendingInvite = ref.watch(pendingInviteProvider) != null;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Image.asset('assets/img/logo/logo.png', height: 132, fit: BoxFit.contain),
              const SizedBox(height: 16),
              Text('Love Tracking', textAlign: TextAlign.center, style: displayText(32, color: scheme.onSurface)),
              const SizedBox(height: 12),
              Text(
                'Lihat lokasi, baterai, dan jaringan pasanganmu secara real-time.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: scheme.onSurfaceVariant),
              ),
              if (hasPendingInvite) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(children: [
                    const Icon(Symbols.mail_rounded, size: 28, color: AppColors.love),
                    const SizedBox(height: 4),
                    Text(
                      'Kamu punya undangan!',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: scheme.onSurface),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Masuk dulu untuk terhubung dengan pasanganmu.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: scheme.onSurface),
                    ),
                  ]),
                ),
              ],
              const Spacer(),
              FilledButton.icon(
                onPressed: _busy ? null : _signIn,
                icon: busyIcon(_busy, Symbols.login_rounded),
                label: const Text('Masuk dengan Google'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
