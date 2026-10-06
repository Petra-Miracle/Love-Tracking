import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../data/api_client.dart';

/// Brand colors from the design system (Pendev/Love-Tracking.pen).
class AppColors {
  static const love = Color(0xFFE91E63);
  static const me = Color(0xFF2979FF);
  static const stale = Color(0xFF9E9E9E);

  static Color success(Brightness b) => b == Brightness.light ? const Color(0xFF2E7D32) : const Color(0xFF66BB6A);
}

/// Shadow used by every card floating above the map.
const floatingShadow = [BoxShadow(color: Color(0x33000000), offset: Offset(0, 4), blurRadius: 12)];

/// Poppins (bundled in assets/fonts), used for titles ("Love Tracking", "Kamu & Budi",
/// screen titles, invite code). Body text uses Android's default Roboto.
TextStyle displayText(double size, {FontWeight weight = FontWeight.w600, Color? color, double? letterSpacing}) =>
    TextStyle(fontFamily: 'Poppins', fontSize: size, fontWeight: weight, color: color, letterSpacing: letterSpacing);

ColorScheme _scheme(Brightness b) {
  final light = b == Brightness.light;
  return ColorScheme.fromSeed(seedColor: AppColors.love, brightness: b).copyWith(
    primary: AppColors.love,
    onPrimary: Colors.white,
    primaryContainer: light ? const Color(0xFFFFD9E2) : const Color(0xFF8C1D4F),
    onPrimaryContainer: light ? const Color(0xFF201A1B) : const Color(0xFFEDE0E1),
    surface: light ? const Color(0xFFFFF8F8) : const Color(0xFF201A1B),
    surfaceContainer: light ? const Color(0xFFFBEAEE) : const Color(0xFF2E2627),
    surfaceContainerHighest: light ? const Color(0xFFF0DFE2) : const Color(0xFF3B3133),
    onSurface: light ? const Color(0xFF201A1B) : const Color(0xFFEDE0E1),
    onSurfaceVariant: light ? const Color(0xFF514347) : const Color(0xFFD6C2C6),
    outline: light ? const Color(0xFF847377) : const Color(0xFF9E8C90),
    error: light ? const Color(0xFFBA1A1A) : const Color(0xFFFFB4AB),
    errorContainer: light ? const Color(0xFFFFDAD6) : const Color(0xFF93000A),
    onErrorContainer: light ? const Color(0xFF410002) : const Color(0xFFFFDAD6),
  );
}

ThemeData buildTheme(Brightness brightness) {
  final scheme = _scheme(brightness);
  final base = ThemeData(colorScheme: scheme, useMaterial3: true, brightness: brightness, fontFamily: 'Roboto');
  const labelStyle = WidgetStatePropertyAll(TextStyle(fontFamily: 'Roboto', fontSize: 16, fontWeight: FontWeight.w600));
  const buttonShape = WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))));
  const buttonSize = WidgetStatePropertyAll(Size.fromHeight(52));
  const buttonPadding = WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 24));

  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        minimumSize: buttonSize,
        padding: buttonPadding,
        shape: buttonShape,
        textStyle: labelStyle,
        iconSize: const WidgetStatePropertyAll(20),
        elevation: const WidgetStatePropertyAll(0),
        // Disabled/loading keeps the brand color, just faded (see "1C – Login Loading").
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled) ? AppColors.love.withValues(alpha: 0.6) : AppColors.love,
        ),
        foregroundColor: const WidgetStatePropertyAll(Colors.white),
        iconColor: const WidgetStatePropertyAll(Colors.white),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        minimumSize: buttonSize,
        padding: buttonPadding,
        shape: buttonShape,
        textStyle: labelStyle,
        iconSize: const WidgetStatePropertyAll(20),
        foregroundColor: const WidgetStatePropertyAll(AppColors.love),
        iconColor: const WidgetStatePropertyAll(AppColors.love),
        side: WidgetStatePropertyAll(BorderSide(color: scheme.outline)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        foregroundColor: const WidgetStatePropertyAll(AppColors.love),
        textStyle: const WidgetStatePropertyAll(TextStyle(fontFamily: 'Roboto', fontSize: 14, fontWeight: FontWeight.w600)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      titleTextStyle: displayText(24, color: scheme.onSurface),
      contentTextStyle: TextStyle(fontFamily: 'Roboto', fontSize: 14, color: scheme.onSurfaceVariant, height: 1.4),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: scheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: TextStyle(fontFamily: 'Roboto', fontSize: 16, color: scheme.onSurface),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

/// The tonal "Hubungkan" button (primaryContainer + onSurface label).
ButtonStyle tonalButtonStyle(ColorScheme scheme) => FilledButton.styleFrom(
      backgroundColor: scheme.primaryContainer,
      foregroundColor: scheme.onSurface,
      disabledBackgroundColor: scheme.primaryContainer.withValues(alpha: 0.6),
      disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.5),
    );

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

String errorMessage(Object error) => switch (error) {
      ApiException e => e.userMessage,
      GoogleSignInException e => 'Login Google gagal: ${e.description ?? e.code.name}',
      _ => 'Terjadi kesalahan: $error',
    };

/// Shows a small spinner in place of a button icon while busy.
Widget busyIcon(bool busy, IconData icon, {Color color = Colors.white}) => busy
    ? SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2, color: color))
    : Icon(icon);
