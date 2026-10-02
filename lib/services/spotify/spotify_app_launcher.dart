import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import 'spotify_config.dart';

/// Platform-specific access to the Spotify app itself: whether it is
/// installed, opening it, and opening its store listing.
///
/// Installation checks rely on the `spotify` scheme being listed under
/// `<queries>` in AndroidManifest.xml (Android 11+ package visibility).
class SpotifyAppLauncher {
  const SpotifyAppLauncher();

  static final Uri _appUri = Uri.parse('spotify:');

  /// Null when the platform cannot tell (anything other than Android).
  Future<bool?> isInstalled() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      return await canLaunchUrl(_appUri);
    } catch (_) {
      return null;
    }
  }

  Future<bool> openApp() =>
      launchUrl(_appUri, mode: LaunchMode.externalApplication);

  Future<bool> openStore() async {
    const id = SpotifyConfig.androidPackage;
    try {
      if (await launchUrl(
        Uri.parse('market://details?id=$id'),
        mode: LaunchMode.externalApplication,
      )) {
        return true;
      }
    } catch (_) {
      // No Play Store on this device; fall back to the web listing.
    }
    return launchUrl(
      Uri.parse('https://play.google.com/store/apps/details?id=$id'),
      mode: LaunchMode.externalApplication,
    );
  }
}
