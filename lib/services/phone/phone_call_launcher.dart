import 'package:url_launcher/url_launcher.dart';

/// Opens Android's own dialer app with a number pre-filled.
///
/// This uses a `tel:` view intent, which only shows the number in the
/// phone app — it does not place the call itself and needs no CALL_PHONE
/// permission. KAIRO has no Telecom/HFP integration, so it cannot place or
/// control calls directly (see widgets/phone/phone_idle_panel.dart for what
/// is actually known about phone connectivity).
class PhoneCallLauncher {
  const PhoneCallLauncher();

  Future<bool> dial(String number) {
    return launchUrl(Uri(scheme: 'tel', path: number));
  }
}
