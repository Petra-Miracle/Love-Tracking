import 'package:flutter/material.dart';

import '../models/models.dart';

/// Circular profile picture with the first-name initial as fallback.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.user, required this.size, required this.fontSize, this.image});

  final AppUser user;
  final double size;
  final double fontSize;

  /// Overrides the network photo, e.g. a freshly picked image that isn't uploaded yet.
  final ImageProvider? image;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final photo = user.photoUrl;
    final provider = image ?? (photo == null ? null : NetworkImage(photo));
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: scheme.primaryContainer,
      foregroundImage: provider,
      // A broken photo URL falls back to the initial instead of throwing.
      onForegroundImageError: provider == null ? null : (_, _) {},
      child: Text(
        user.firstName.isEmpty ? '?' : user.firstName[0].toUpperCase(),
        style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600, color: scheme.onSurface),
      ),
    );
  }
}
