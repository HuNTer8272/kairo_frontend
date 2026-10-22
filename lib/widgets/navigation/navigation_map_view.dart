import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// A real map (OpenStreetMap tiles via [flutter_map]) instead of a
/// hand-painted illustration — the only way to get an actually
/// recognisable street layout and place names like the reference screenshot.
///
/// The route/origin/destination/vehicle are still a fixed demo path (KAIRO
/// has no routing engine yet), drawn as an overlay on top of a real map of
/// Bandra, Mumbai.
class NavigationMapView extends StatelessWidget {
  const NavigationMapView({
    super.key,
    required this.dark,
    required this.satellite,
    required this.mapController,
  });

  final bool dark;
  final bool satellite;
  final MapController mapController;

  // A short demo route through Bandra, Mumbai — Linking Road toward
  // Bandra Bandstand. Static points standing in for a real routing engine.
  static const _origin = LatLng(19.0545, 72.8302);
  static const _waypointA = LatLng(19.0551, 72.8275);
  static const _waypointB = LatLng(19.0479, 72.8252);
  static const _destination = LatLng(19.0442, 72.8203);

  static const _route = [_origin, _waypointA, _waypointB, _destination];

  /// Where the vehicle marker sits along the demo route — exposed so the
  /// "center vehicle" map control can recenter on it.
  static const vehiclePosition = _waypointA;

  @override
  Widget build(BuildContext context) {
    const routeBlue = Color(0xFF3B82F6);
    return FlutterMap(
      mapController: mapController,
      options: const MapOptions(
        initialCenter: LatLng(19.0500, 72.8260),
        initialZoom: 14.2,
        interactionOptions: InteractionOptions(
          flags: InteractiveFlag.pinchZoom |
              InteractiveFlag.drag |
              InteractiveFlag.doubleTapZoom,
        ),
      ),
      children: [
        if (satellite)
          TileLayer(
            urlTemplate:
                'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
            userAgentPackageName: 'com.kairo.vehicle_tablet_ui',
            maxZoom: 19,
          )
        else
          TileLayer(
            urlTemplate: dark
                ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains:
                dark ? const ['a', 'b', 'c', 'd'] : const ['a', 'b', 'c'],
            userAgentPackageName: 'com.kairo.vehicle_tablet_ui',
            maxZoom: 19,
          ),
        PolylineLayer(polylines: [
          Polyline(
            points: _route,
            strokeWidth: 10,
            color: dark ? Colors.black45 : Colors.white,
            borderStrokeWidth: 2,
          ),
          Polyline(
            points: _route,
            strokeWidth: 6,
            color: routeBlue,
          ),
        ]),
        MarkerLayer(markers: [
          Marker(
            point: _origin,
            width: 18,
            height: 18,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: routeBlue, width: 3),
              ),
            ),
          ),
          Marker(
            point: _destination,
            width: 34,
            height: 34,
            alignment: Alignment.topCenter,
            child: const Icon(Icons.location_on,
                color: Color(0xFFE94B4B), size: 34),
          ),
          Marker(
            point: _waypointA,
            width: 22,
            height: 22,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: routeBlue.withValues(alpha: .20),
              ),
              child: Center(
                child: Container(
                  width: 11,
                  height: 11,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: routeBlue,
                  ),
                ),
              ),
            ),
          ),
        ]),
        RichAttributionWidget(
          alignment: AttributionAlignment.bottomLeft,
          attributions: [
            TextSourceAttribution(
              satellite
                  ? 'Esri, Maxar, Earthstar Geographics'
                  : dark
                      ? 'CARTO | OpenStreetMap contributors'
                      : 'OpenStreetMap contributors',
              textStyle: const TextStyle(fontSize: 10),
            ),
          ],
        ),
      ],
    );
  }
}
