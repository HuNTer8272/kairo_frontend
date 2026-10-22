import 'package:url_launcher/url_launcher.dart';

/// Opens the device's own maps app with a destination pre-filled.
///
/// KAIRO has no routing engine of its own — this hands the destination to
/// whatever maps app (Google Maps, Waze, etc.) is installed via the
/// universal `google.com/maps/dir` link, the same way [PhoneCallLauncher]
/// hands numbers to the phone's dialer instead of placing calls itself.
class NavigationLauncher {
  const NavigationLauncher();

  Future<bool> launch(String destination) {
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': destination,
    });
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
