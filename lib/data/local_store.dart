import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persistent key/value store shared by the UI and the background-service isolate.
class LocalStore {
  const LocalStore();

  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'auth_token';
  static const _pausedKey = 'sharing_paused';
  static const _themeKey = 'theme_mode';

  Future<String?> readToken() => _storage.read(key: _tokenKey);
  Future<void> writeToken(String token) => _storage.write(key: _tokenKey, value: token);
  Future<void> deleteToken() => _storage.delete(key: _tokenKey);

  Future<bool> readSharingPaused() async => await _storage.read(key: _pausedKey) == 'true';
  Future<void> writeSharingPaused(bool paused) =>
      _storage.write(key: _pausedKey, value: paused.toString());

  /// 'system' | 'light' | 'dark'
  Future<String?> readThemeMode() => _storage.read(key: _themeKey);
  Future<void> writeThemeMode(String mode) => _storage.write(key: _themeKey, value: mode);
}
