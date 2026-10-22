import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../services/apollo/apollo_service.dart';
import '../services/navigation/geocoding_service.dart';
import '../services/navigation/navigation_launcher.dart';
import '../services/navigation/recent_destinations_service.dart';
import '../services/navigation/saved_places_service.dart';
import '../widgets/apollo/apollo_navigation_view.dart';
import '../widgets/navigation/add_place_dialog.dart';
import '../widgets/navigation/edit_place_dialog.dart';
import '../widgets/navigation/navigation_map_view.dart';
import '../widgets/navigation/navigation_search_panel.dart';

/// KAIRO has no map rendering or routing engine of its own. This screen's
/// canvas map is a stylised backdrop; the real functionality is handing a
/// destination off to the device's own maps app, which is what every
/// action here (places, search, recents) ultimately does. See
/// [NavigationLauncher].
///
/// The exception is Apollo: while the KAIRO gateway is live, this screen
/// shows Apollo's HD map instead, where destinations are driven to by the
/// car itself (see [ApolloNavigationView]). The street map stays one tap
/// away.
class NavigationScreen extends StatefulWidget {
  const NavigationScreen({
    super.key,
    this.onClose,
    required this.places,
    required this.recents,
    this.launcher = const NavigationLauncher(),
    this.geocoder = const GeocodingService(),
    this.apollo,
  });

  final VoidCallback? onClose;
  final SavedPlacesService places;
  final RecentDestinationsService recents;
  final NavigationLauncher launcher;
  final GeocodingService geocoder;
  final ApolloService? apollo;

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  bool rearView = false;
  bool satellite = false;
  bool _searching = false;
  bool _launching = false;
  final _mapController = MapController();

  /// Driver chose the street map over Apollo's HD map.
  bool _streetMap = false;
  bool _apolloAvailable = false;

  @override
  void initState() {
    super.initState();
    widget.apollo?.addListener(_onApolloChanged);
    _apolloAvailable = _computeApolloAvailable();
  }

  @override
  void dispose() {
    widget.apollo?.removeListener(_onApolloChanged);
    _mapController.dispose();
    super.dispose();
  }

  bool _computeApolloAvailable() {
    final apollo = widget.apollo;
    return apollo != null &&
        apollo.isLive &&
        (apollo.hdMap != null || apollo.loadingMap);
  }

  /// Rebuild only when Apollo comes or goes, not on every state push.
  void _onApolloChanged() {
    final available = _computeApolloAvailable();
    if (available != _apolloAvailable) {
      setState(() => _apolloAvailable = available);
    }
  }

  void _zoomBy(double delta) {
    final camera = _mapController.camera;
    _mapController.move(camera.center, camera.zoom + delta);
  }

  void _centerOnVehicle() {
    _mapController.move(NavigationMapView.vehiclePosition, 15);
  }

  Future<void> _navigateTo(String destination) async {
    if (_searching) setState(() => _searching = false);
    if (_launching) return;
    setState(() => _launching = true);
    try {
      await widget.recents.add(destination);
      final opened = await widget.launcher.launch(destination);
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No maps app available on this device')),
        );
      }
    } finally {
      if (mounted) setState(() => _launching = false);
    }
  }

  Future<void> _editPlace(SavedPlace place) async {
    final result = await showEditPlaceDialog(context,
        place: place, geocoder: widget.geocoder);
    if (result == null) return;
    if (result.delete) {
      await widget.places.remove(place.id);
      return;
    }
    if (result.label != place.label) {
      await widget.places.rename(place.id, result.label);
    }
    await widget.places.setAddress(place.id, result.address);
  }

  Future<void> _addPlace() async {
    final label = await showAddPlaceDialog(context);
    if (label == null || label.trim().isEmpty) return;
    await widget.places.addPlace(label);
    final created = widget.places.places.last;
    if (mounted) await _editPlace(created);
  }

  @override
  Widget build(BuildContext context) {
    if (_apolloAvailable && !_streetMap) {
      return Material(
        color: Theme.of(context).colorScheme.surface,
        child: ApolloNavigationView(
          apollo: widget.apollo!,
          onShowStreetMap: () => setState(() => _streetMap = true),
          onClose: widget.onClose,
        ),
      );
    }
    return _buildStreetMap(context);
  }

  Widget _buildStreetMap(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final darkMap = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: scheme.surface,
      child: Stack(
        children: [
          Positioned.fill(
            child: NavigationMapView(
              dark: darkMap,
              satellite: satellite,
              mapController: _mapController,
            ),
          ),
          if (_searching)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _searching = false),
                child: Container(color: Colors.black26),
              ),
            ),
          Positioned(
            left: 20,
            top: 76,
            bottom: 24,
            width: 240,
            child: ListenableBuilder(
              listenable: Listenable.merge([widget.places, widget.recents]),
              builder: (context, _) => _DrivePanel(
                rearView: rearView,
                dark: darkMap,
                onToggle: () => setState(() => rearView = !rearView),
                places: widget.places,
                recents: widget.recents,
                busy: _launching,
                onTapPlace: (place) {
                  if (place.address == null) {
                    _editPlace(place);
                  } else {
                    _navigateTo(place.address!);
                  }
                },
                onEditPlace: _editPlace,
                onAddPlace: _addPlace,
                onTapRecent: _navigateTo,
              ),
            ),
          ),
          Positioned(
            top: 76,
            left: 274,
            right: 24,
            child: _searching
                ? ListenableBuilder(
                    listenable: widget.recents,
                    builder: (context, _) => NavigationSearchPanel(
                      places: widget.places,
                      recents: widget.recents.recents,
                      onSubmit: _navigateTo,
                      onClose: () => setState(() => _searching = false),
                      geocoder: widget.geocoder,
                    ),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: Material(
                          color: darkMap
                              ? const Color(0xD91B2022)
                              : Colors.white.withValues(alpha: .94),
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => setState(() => _searching = true),
                            child: Container(
                              height: 48,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: const [
                                  BoxShadow(
                                      blurRadius: 18,
                                      color: Color(0x18000000))
                                ],
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.search_rounded,
                                      color: scheme.primary),
                                  const SizedBox(width: 10),
                                  Text(
                                    rearView ? 'Rear map view' : 'Navigate',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (_apolloAvailable) ...[
                        _MapButton(
                          icon: Icons.assistant_navigation,
                          tooltip: 'Apollo HD map',
                          onPressed: () => setState(() => _streetMap = false),
                        ),
                        const SizedBox(width: 8),
                      ],
                      _MapButton(
                        icon: satellite
                            ? Icons.layers_rounded
                            : Icons.map_outlined,
                        tooltip: 'Map layers',
                        onPressed: () =>
                            setState(() => satellite = !satellite),
                      ),
                      const SizedBox(width: 8),
                      _MapButton(
                          icon: Icons.close_rounded,
                          tooltip: 'Close map',
                          onPressed: widget.onClose),
                    ],
                  ),
          ),
          if (!_searching) ...[
            Positioned(
              right: 24,
              bottom: 24,
              child: Column(
                children: [
                  _MapButton(
                      icon: Icons.add_rounded,
                      tooltip: 'Zoom in',
                      onPressed: () => _zoomBy(1)),
                  const SizedBox(height: 2),
                  _MapButton(
                      icon: Icons.remove_rounded,
                      tooltip: 'Zoom out',
                      onPressed: () => _zoomBy(-1)),
                  const SizedBox(height: 10),
                  _MapButton(
                      icon: Icons.my_location_rounded,
                      tooltip: 'Center vehicle',
                      onPressed: _centerOnVehicle),
                ],
              ),
            ),
            Positioned(
              left: 294,
              bottom: 26,
              child: Text(
                satellite ? 'Satellite map' : 'Standard map  |  500 m',
                style: TextStyle(
                    color: darkMap ? Colors.white70 : const Color(0xFF4D565A),
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DrivePanel extends StatelessWidget {
  const _DrivePanel({
    required this.rearView,
    required this.dark,
    required this.onToggle,
    required this.places,
    required this.recents,
    required this.busy,
    required this.onTapPlace,
    required this.onEditPlace,
    required this.onAddPlace,
    required this.onTapRecent,
  });

  final bool rearView;
  final bool dark;
  final VoidCallback onToggle;
  final SavedPlacesService places;
  final RecentDestinationsService recents;
  final bool busy;
  final ValueChanged<SavedPlace> onTapPlace;
  final ValueChanged<SavedPlace> onEditPlace;
  final VoidCallback onAddPlace;
  final ValueChanged<String> onTapRecent;

  @override
  Widget build(BuildContext context) {
    final background =
        dark ? const Color(0xE814181A) : Colors.white.withValues(alpha: .96);
    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(blurRadius: 18, color: Color(0x18000000))
                ]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Text('NAVIGATION',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.3)),
                  const Spacer(),
                  if (busy)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    )
                  else
                    Icon(Icons.more_horiz_rounded,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary)
                ]),
                const SizedBox(height: 12),
                Text(rearView ? 'Rear camera map' : '29',
                    style: const TextStyle(
                        fontSize: 34, fontWeight: FontWeight.w700, height: .9)),
                Text(rearView ? 'Vehicle position' : 'min',
                    style: TextStyle(
                        color: dark ? Colors.white60 : Colors.black54,
                        fontSize: 12)),
                const Divider(height: 24),
                Row(children: [
                  Icon(Icons.turn_right_rounded,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  const Expanded(
                      child: Text('300 m\nLinking Road, Bandra',
                          style: TextStyle(fontWeight: FontWeight.w600)))
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  Icon(
                      rearView
                          ? Icons.camera_rear_rounded
                          : Icons.navigation_rounded,
                      size: 17,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(rearView ? 'Rear view' : 'Drive view')),
                  Switch.adaptive(value: rearView, onChanged: (_) => onToggle())
                ]),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
                color: background, borderRadius: BorderRadius.circular(8)),
            child: Column(
              children: [
                for (final place in places.places)
                  _PlaceRow(
                    label: place.label,
                    icon: switch (place.id) {
                      'home' => Icons.home_rounded,
                      'work' => Icons.work_rounded,
                      _ => Icons.place_rounded,
                    },
                    address: place.address,
                    dark: dark,
                    onTap: () => onTapPlace(place),
                    onEdit: () => onEditPlace(place),
                  ),
                InkWell(
                  onTap: onAddPlace,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(children: [
                      Icon(Icons.add_rounded,
                          size: 18,
                          color: dark ? Colors.white60 : Colors.black54),
                      const SizedBox(width: 8),
                      Text('Add a place',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: dark ? Colors.white60 : Colors.black54)),
                    ]),
                  ),
                ),
              ],
            ),
          ),
          if (recents.recents.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 8),
              decoration: BoxDecoration(
                  color: background, borderRadius: BorderRadius.circular(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('RECENT',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                          color: dark ? Colors.white60 : Colors.black45)),
                  const SizedBox(height: 4),
                  for (final destination in recents.recents)
                    _RecentRow(
                      destination: destination,
                      dark: dark,
                      onTap: () => onTapRecent(destination),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlaceRow extends StatelessWidget {
  const _PlaceRow({
    required this.label,
    required this.icon,
    required this.address,
    required this.dark,
    required this.onTap,
    required this.onEdit,
  });

  final String label;
  final IconData icon;
  final String? address;
  final bool dark;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  address ?? 'Tap to set',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: dark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            iconSize: 16,
            visualDensity: VisualDensity.compact,
            tooltip: 'Edit $label address',
            icon: Icon(Icons.edit_outlined,
                color: dark ? Colors.white54 : Colors.black45),
            onPressed: onEdit,
          ),
        ]),
      ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({
    required this.destination,
    required this.dark,
    required this.onTap,
  });

  final String destination;
  final bool dark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Icon(Icons.history_rounded,
              size: 16, color: dark ? Colors.white54 : Colors.black45),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              destination,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ]),
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton(
      {required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xE81B2022)
            : Colors.white.withValues(alpha: .96),
        borderRadius: BorderRadius.circular(8),
        child: IconButton(
            onPressed: onPressed,
            icon: Icon(icon),
            constraints: const BoxConstraints.tightFor(width: 48, height: 48)),
      ),
    );
  }
}
