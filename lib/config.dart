/// Build-time configuration, supplied with
/// `flutter run --dart-define-from-file=config/dev.json`.
class AppConfig {
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const pusherKey = String.fromEnvironment('PUSHER_KEY');
  static const pusherCluster = String.fromEnvironment('PUSHER_CLUSTER', defaultValue: 'ap1');

  /// OAuth "Web application" client ID. The backend verifies the Google ID
  /// token against this audience.
  static const googleServerClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

  static const inviteScheme = 'lovetracking';
  static const inviteHost = 'invite';

  static List<String> get missingKeys => [
        if (apiBaseUrl.isEmpty) 'API_BASE_URL',
        if (pusherKey.isEmpty) 'PUSHER_KEY',
        if (googleServerClientId.isEmpty) 'GOOGLE_SERVER_CLIENT_ID',
      ];
}
