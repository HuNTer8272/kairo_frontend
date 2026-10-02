/// Static configuration for the Spotify integration.
///
/// The client ID is supplied at build time so no account-specific value
/// lives in source control. Copy dart_defines.example.json to the
/// gitignored dart_defines.json, fill it in, then:
///
/// ```
/// flutter run --dart-define-from-file=dart_defines.json
/// flutter build apk --release --dart-define-from-file=dart_defines.json
/// ```
///
/// No client secret is used anywhere: sign-in uses Authorization Code with
/// PKCE, which Spotify supports for apps that cannot keep a secret.
abstract final class SpotifyConfig {
  static const String clientId = String.fromEnvironment('SPOTIFY_CLIENT_ID');

  /// Must be registered in the Spotify developer dashboard, and its scheme
  /// must match the CallbackActivity intent filter in AndroidManifest.xml.
  static const String redirectUri = 'vehicletablet://spotify-callback';
  static const String callbackScheme = 'vehicletablet';

  static const List<String> scopes = [
    'user-read-playback-state',
    'user-read-currently-playing',
    'user-modify-playback-state',
  ];

  static const String androidPackage = 'com.spotify.music';

  static bool get isConfigured => clientId.isNotEmpty;
}
