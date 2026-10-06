import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:share_plus/share_plus.dart';

import '../models/models.dart';
import '../providers.dart';
import 'format.dart';
import 'profile_screen.dart';
import 'theme.dart';

/// Frames "2 – Hubungkan Pasangan Awal", "3 – Kode Dibuat", "4A – Kode Terisi Menghubungkan".
class PairingScreen extends ConsumerStatefulWidget {
  const PairingScreen({super.key});

  @override
  ConsumerState<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends ConsumerState<PairingScreen> {
  final _codeController = TextEditingController();
  Invite? _invite;
  bool _creating = false;
  bool _joining = false;

  @override
  void initState() {
    super.initState();
    // A deep link may have arrived before this screen was shown.
    WidgetsBinding.instance.addPostFrameCallback((_) => _consumePendingInvite(ref.read(pendingInviteProvider)));
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _consumePendingInvite(String? code) {
    if (code == null || !mounted) return;
    ref.read(pendingInviteProvider.notifier).clear();
    _codeController.text = code;
    _join();
  }

  Future<void> _createInvite() async {
    setState(() => _creating = true);
    try {
      final invite = await ref.read(sessionProvider.notifier).createInvite();
      if (mounted) setState(() => _invite = invite);
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _join() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length != 6) {
      showSnack(context, 'Kode undangan terdiri dari 6 karakter.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _joining = true);
    try {
      await ref.read(sessionProvider.notifier).acceptInvite(code);
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e));
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  void _share(Invite invite) {
    final name = ref.read(sessionProvider).value?.user.firstName ?? '';
    SharePlus.instance.share(ShareParams(
      subject: 'Undangan Love Tracking',
      text: '$name mengajakmu terhubung di Love Tracking 💕\n\n'
          'Buka link ini di HP yang sudah terpasang aplikasinya:\n${invite.link}\n\n'
          'Atau masukkan kode: ${invite.code}',
    ));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(pendingInviteProvider, (_, code) => _consumePendingInvite(code));
    final scheme = Theme.of(context).colorScheme;
    final user = ref.watch(sessionProvider).value?.user;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            Row(children: [
              Expanded(child: Text('Hubungkan Pasangan', style: displayText(22, color: scheme.onSurface))),
              IconButton(
                tooltip: 'Profil',
                icon: Icon(Symbols.account_circle_rounded, size: 20, color: scheme.onSurfaceVariant),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const ProfileScreen()),
                ),
              ),
              IconButton(
                tooltip: 'Keluar',
                icon: Icon(Symbols.logout_rounded, size: 18, color: scheme.onSurfaceVariant),
                onPressed: () => ref.read(sessionProvider.notifier).signOut(),
              ),
            ]),
            const SizedBox(height: 16),
            Text(
              'Hai, ${user?.firstName ?? ''} 👋',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: scheme.onSurface),
            ),
            const SizedBox(height: 16),
            Text(
              'Hubungkan akunmu dengan pasangan. Salah satu dari kalian membuat kode, '
              'yang lain memasukkannya.',
              style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              icon: Symbols.favorite_rounded,
              title: 'Undang pasangan',
              children: _invite == null
                  ? [
                      FilledButton.icon(
                        onPressed: _creating ? null : _createInvite,
                        icon: busyIcon(_creating, Symbols.add_link_rounded),
                        label: const Text('Buat kode undangan'),
                      ),
                    ]
                  : _inviteChildren(_invite!, scheme),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              icon: Symbols.vpn_key_rounded,
              title: 'Punya kode dari pasangan?',
              children: [
                TextField(
                  controller: _codeController,
                  enabled: !_joining,
                  textCapitalization: TextCapitalization.characters,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 8,
                    color: scheme.onSurface,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
                    TextInputFormatter.withFunction((_, v) => v.copyWith(text: v.text.toUpperCase())),
                  ],
                  decoration: InputDecoration(
                    hintText: 'XXXXXX',
                    hintStyle: TextStyle(color: scheme.outline, fontWeight: FontWeight.w600, letterSpacing: 8),
                    counterText: '',
                    filled: true,
                    fillColor: scheme.surfaceContainerHighest,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppColors.love, width: 1.5),
                    ),
                  ),
                  onSubmitted: (_) => _join(),
                ),
                FilledButton(
                  onPressed: _joining ? null : _join,
                  style: tonalButtonStyle(scheme),
                  child: Text(_joining ? 'Menghubungkan…' : 'Hubungkan'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _inviteChildren(Invite invite, ColorScheme scheme) {
    final expires = formatClock(invite.expiresAt);
    return [
      Text(
        invite.code,
        textAlign: TextAlign.center,
        style: displayText(40, weight: FontWeight.w700, color: AppColors.love, letterSpacing: 8),
      ),
      Text(
        'Berlaku sampai besok pukul $expires. Menunggu pasangan bergabung…',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
      ),
      Row(children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: invite.code));
              showSnack(context, 'Kode disalin');
            },
            icon: const Icon(Symbols.content_copy_rounded),
            label: const Text('Salin'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _share(invite),
            icon: const Icon(Symbols.share_rounded),
            label: const Text('Bagikan'),
          ),
        ),
      ]),
      TextButton(onPressed: _creating ? null : _createInvite, child: const Text('Buat kode baru')),
    ];
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.icon, required this.title, required this.children});

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: scheme.surfaceContainer, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Row(children: [
            Icon(icon, size: 22, color: AppColors.love),
            const SizedBox(width: 8),
            Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: scheme.onSurface)),
          ]),
          ...children,
        ],
      ),
    );
  }
}
