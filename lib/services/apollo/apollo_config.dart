/// Where the tablet finds the KAIRO vehicle gateway (kairo_gateway in the
/// Kairo repo), which fronts Apollo Cyber RT and Dreamview Plus.
///
/// Set at build time with `--dart-define=KAIRO_GATEWAY_URL=http://<pc-ip>:8090`
/// (or the same key in dart_defines.json). The default reaches the host PC
/// from the Android emulator. It can also be changed at runtime from
/// Settings > Autopilot; that choice is persisted and wins over the default.
abstract final class ApolloConfig {
  static const String defaultGatewayUrl = String.fromEnvironment(
    'KAIRO_GATEWAY_URL',
    defaultValue: 'http://10.0.2.2:8090',
  );

  /// Cruise speed used for new routes until the driver picks another one.
  static const double defaultCruiseKph = 30;
  static const double minCruiseKph = 10;
  static const double maxCruiseKph = 60;
}
