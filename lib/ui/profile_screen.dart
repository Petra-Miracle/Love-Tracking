import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../models/models.dart';
import '../providers.dart';
import 'theme.dart';
import 'theme_picker.dart';
import 'widgets.dart';

/// Frame "Profil": change display name and profile picture.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

enum _PhotoAction { gallery, camera, remove }

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final TextEditingController _name;
  ({Uint8List bytes, String mimeType})? _newPhoto;
  bool _removePhoto = false;
  bool _saving = false;
  bool _nameLoaded = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _changePhoto() async {
    final user = ref.read(sessionProvider).value?.user;
    final canRemove = (_newPhoto != null) || ((user?.hasCustomPhoto ?? false) && !_removePhoto);
    final action = await showModalBottomSheet<_PhotoAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Symbols.photo_library_rounded),
            title: const Text('Pilih dari galeri'),
            onTap: () => Navigator.pop(context, _PhotoAction.gallery),
          ),
          ListTile(
            leading: const Icon(Symbols.photo_camera_rounded),
            title: const Text('Ambil foto'),
            onTap: () => Navigator.pop(context, _PhotoAction.camera),
          ),
          if (canRemove)
            ListTile(
              leading: const Icon(Symbols.delete_rounded),
              title: const Text('Gunakan foto akun Google'),
              onTap: () => Navigator.pop(context, _PhotoAction.remove),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (action == null || !mounted) return;

    if (action == _PhotoAction.remove) {
      setState(() {
        _newPhoto = null;
        _removePhoto = true;
      });
      return;
    }

    try {
      // Resized and re-encoded on the device so uploads stay small (well under 1 MB).
      final file = await ImagePicker().pickImage(
        source: action == _PhotoAction.camera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
        preferredCameraDevice: CameraDevice.front,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final path = file.path.toLowerCase();
      final mimeType = path.endsWith('.png')
          ? 'image/png'
          : path.endsWith('.webp')
              ? 'image/webp'
              : 'image/jpeg';
      setState(() {
        _newPhoto = (bytes: bytes, mimeType: mimeType);
        _removePhoto = false;
      });
    } catch (e) {
      if (mounted) showSnack(context, 'Tidak bisa membuka foto: $e');
    }
  }

  Future<void> _save() async {
    final user = ref.read(sessionProvider).value?.user;
    if (user == null) return;
    final name = _name.text.trim();
    if (name.isEmpty || name.length > 40) {
      showSnack(context, 'Nama harus 1–40 karakter.');
      return;
    }
    final nameChanged = name != user.name;
    if (!nameChanged && _newPhoto == null && !_removePhoto) {
      Navigator.pop(context);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      await ref.read(sessionProvider.notifier).saveProfile(
            name: nameChanged ? name : null,
            photo: _newPhoto,
            removePhoto: _removePhoto,
          );
      if (!mounted) return;
      showSnack(context, 'Profil disimpan');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final user = ref.watch(sessionProvider).value?.user;
    if (user == null) return const Scaffold();
    if (!_nameLoaded) {
      _name.text = user.name;
      _nameLoaded = true;
    }

    final preview = _newPhoto != null ? MemoryImage(_newPhoto!.bytes) : null;
    // The Google photo URL isn't known locally, so "use Google photo" previews the initial.
    final shownUser = _removePhoto
        ? AppUser(id: user.id, email: user.email, name: user.name)
        : user;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 24, 24),
          children: [
            Row(children: [
              IconButton(
                tooltip: 'Kembali',
                icon: Icon(Symbols.arrow_back_rounded, color: scheme.onSurface),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 4),
              Text('Profil', style: displayText(22, color: scheme.onSurface)),
            ]),
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SizedBox(height: 36),
                Center(
                  child: GestureDetector(
                    onTap: _saving ? null : _changePhoto,
                    child: SizedBox.square(
                      dimension: 120,
                      child: Stack(children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.love, width: 3),
                          ),
                          child: UserAvatar(user: shownUser, size: 114, fontSize: 44, image: preview),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.love,
                              shape: BoxShape.circle,
                              border: Border.all(color: scheme.surface, width: 2),
                            ),
                            child: const Icon(Symbols.photo_camera_rounded, size: 18, color: Colors.white),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: TextButton(
                    onPressed: _saving ? null : _changePhoto,
                    child: const Text('Ubah foto profil'),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Nama pengguna',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _name,
                  enabled: !_saving,
                  maxLength: 40,
                  textCapitalization: TextCapitalization.words,
                  style: TextStyle(fontSize: 16, color: scheme.onSurface),
                  decoration: InputDecoration(
                    prefixIcon: Icon(Symbols.person_rounded, size: 18, color: scheme.onSurfaceVariant),
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: scheme.outline),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: scheme.outline),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppColors.love, width: 1.5),
                    ),
                  ),
                  onSubmitted: (_) => _save(),
                ),
                const SizedBox(height: 8),
                Text(
                  'Nama ini terlihat oleh pasanganmu.',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: busyIcon(_saving, Symbols.save_rounded),
                  label: const Text('Simpan'),
                ),
                const SizedBox(height: 32),
                Text(
                  'Tampilan',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                const ThemeModeSelector(),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
