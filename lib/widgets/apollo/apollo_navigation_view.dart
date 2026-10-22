import 'package:flutter/material.dart';

import '../../models/apollo_state.dart';
import '../../services/apollo/apollo_config.dart';
import '../../services/apollo/apollo_service.dart';
import '../../theme/app_colors.dart';
import 'apollo_map_view.dart';
import 'autopilot_format.dart';
import 'manual_drive_controls.dart';

/// Navigation on Apollo's own HD map: the car, its route and planned path
/// are live from Apollo, and every destination set here is a real Apollo
/// lane-follow command that Dreamview shows too.
///
/// Tap the map to drop a pin, then drive there, save it as a place, or (in
/// Sim Control) move the car to it.
class ApolloNavigationView extends StatefulWidget {
  const ApolloNavigationView({
    super.key,
    required this.apollo,
    required this.onShowStreetMap,
    this.onClose,
  });

  final ApolloService apollo;
  final VoidCallback onShowStreetMap;
  final VoidCallback? onClose;

  @override
  State<ApolloNavigationView> createState() => _ApolloNavigationViewState();
}

class _ApolloNavigationViewState extends State<ApolloNavigationView> {
  final _camera = ApolloMapController();
  Offset? _pin;

  /// Lane check for [_pin]: null while checking.
  LaneSnap? _pinSnap;
  bool _pinChecked = false;

  /// Drops a pin, then moves it onto the nearest lane (where Apollo will
  /// actually drive to) or flags it as off-road.
  Future<void> _dropPin(Offset tap) async {
    setState(() {
      _pin = tap;
      _pinSnap = null;
      _pinChecked = false;
    });
    final snap = await apollo.snap(tap.dx, tap.dy);
    if (!mounted || _pin != tap) return;
    setState(() {
      _pinSnap = snap;
      _pinChecked = true;
      if (snap != null && snap.onRoad) _pin = snap.point;
    });
  }

  ApolloService get apollo => widget.apollo;

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  Future<void> _goTo(Offset point, {String? name}) async {
    final ok = await apolloAction(
      context,
      apollo.go(point.dx, point.dy, name: name),
    );
    if (ok && mounted) {
      setState(() => _pin = null);
      _camera.recenter();
    }
  }

  Future<void> _savePin(String id, String label) async {
    final pin = _pin;
    if (pin == null) return;
    final ok = await apolloAction(
      context,
      apollo.savePlace(id, label, pin.dx, pin.dy),
      success: '$label saved',
    );
    if (ok && mounted) setState(() => _pin = null);
  }

  Future<void> _moveCarToPin() async {
    final pin = _pin;
    if (pin == null) return;
    final ok = await apolloAction(
      context,
      apollo.setStartPoint(x: pin.dx, y: pin.dy, heading: 0),
      success: 'Car moved',
    );
    if (ok && mounted) {
      setState(() => _pin = null);
      _camera.recenter();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ListenableBuilder(
      listenable: apollo,
      builder: (context, _) {
        final map = apollo.hdMap;
        final state = apollo.state;
        if (map == null) {
          return Center(
            child: apollo.mapError != null
                ? Text(apollo.mapError!)
                : const CircularProgressIndicator(),
          );
        }
        return Stack(
          children: [
            Positioned.fill(
              child: ApolloMapView(
                map: map,
                controller: _camera,
                state: state,
                pin: _pin,
                dark: dark,
                onTapWorld: _dropPin,
              ),
            ),
            Positioned(
              left: 20,
              top: 76,
              bottom: 24,
              width: 240,
              child: _DrivePanel(
                apollo: apollo,
                dark: dark,
                onGoToPlace: (place) => _goTo(place.offset, name: place.label),
              ),
            ),
            Positioned(
              top: 76,
              left: 274,
              right: 24,
              child: Row(
                children: [
                  Expanded(
                    child: _Glass(
                      dark: dark,
                      child: SizedBox(
                        height: 48,
                        child: Row(
                          children: [
                            const SizedBox(width: 16),
                            Icon(Icons.touch_app_outlined,
                                color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Tap the map to choose where to drive',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                            Text(
                              state?.dreamview.map ?? map.name,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: dark ? Colors.white60 : Colors.black45,
                              ),
                            ),
                            const SizedBox(width: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _MapButton(
                    icon: Icons.public_rounded,
                    tooltip: 'Street map',
                    onPressed: widget.onShowStreetMap,
                  ),
                  const SizedBox(width: 8),
                  _MapButton(
                    icon: Icons.close_rounded,
                    tooltip: 'Close map',
                    onPressed: widget.onClose,
                  ),
                ],
              ),
            ),
            Positioned(
              right: 24,
              bottom: 24,
              child: ListenableBuilder(
                listenable: _camera,
                builder: (context, _) => Column(
                  children: [
                    _MapButton(
                      icon: Icons.add_rounded,
                      tooltip: 'Zoom in',
                      onPressed: () => _camera.zoomBy(1.5),
                    ),
                    const SizedBox(height: 2),
                    _MapButton(
                      icon: Icons.remove_rounded,
                      tooltip: 'Zoom out',
                      onPressed: () => _camera.zoomBy(1 / 1.5),
                    ),
                    const SizedBox(height: 10),
                    _MapButton(
                      icon: _camera.follow
                          ? Icons.my_location_rounded
                          : Icons.location_searching_rounded,
                      tooltip: 'Follow vehicle',
                      onPressed: _camera.recenter,
                    ),
                  ],
                ),
              ),
            ),
            if (state?.drive.manual ?? false)
              Positioned(
                left: 274,
                right: 96,
                bottom: 24,
                child: Center(child: ManualDriveControls(apollo: apollo)),
              ),
            if (_pin != null)
              Positioned(
                left: 274,
                right: 96,
                bottom: (state?.drive.manual ?? false) ? 214 : 24,
                child: Center(
                  child: _PinCard(
                    pin: _pin!,
                    dark: dark,
                    canDrive: apollo.canDrive,
                    checked: _pinChecked,
                    onRoad: _pinSnap?.onRoad ?? false,
                    simControl: state?.dreamview.simControl ?? false,
                    going: apollo.isPending('go'),
                    onGo: () => _goTo(_pin!),
                    onSaveHome: () => _savePin('home', 'Home'),
                    onSaveWork: () => _savePin('work', 'Work'),
                    onMoveCar: _moveCarToPin,
                    onDismiss: () => setState(() => _pin = null),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DrivePanel extends StatelessWidget {
  const _DrivePanel({
    required this.apollo,
    required this.dark,
    required this.onGoToPlace,
  });

  final ApolloService apollo;
  final bool dark;
  final ValueChanged<ApolloPlace> onGoToPlace;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final state = apollo.state;
    final ap = state?.autopilot;
    final muted = dark ? Colors.white60 : Colors.black54;
    final onTrip = ap != null &&
        ap.hasRoute &&
        ap.phase != AutopilotPhase.ready &&
        ap.phase != AutopilotPhase.manual;
    final manual = state?.drive.manual ?? false;

    Future<void> run(Future<String?> Function() action) async {
      apolloAction(context, action());
    }

    final places = <ApolloPlace>[
      state?.places['home'] ??
          const ApolloPlace(id: 'home', label: 'Home', x: 0, y: 0),
      state?.places['work'] ??
          const ApolloPlace(id: 'work', label: 'Work', x: 0, y: 0),
      for (final entry in (state?.places ?? const {}).entries)
        if (entry.key != 'home' && entry.key != 'work') entry.value,
    ];

    return SingleChildScrollView(
      child: Column(
        children: [
          _Glass(
            dark: dark,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Text('AUTOPILOT',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.3)),
                  const Spacer(),
                  StatusDot(color: AutopilotFormat.color(apollo, scheme)),
                ]),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      onTrip
                          ? AutopilotFormat.eta(ap.etaS).replaceAll(' min', '')
                          : '${state?.vehicle.speedKph.round() ?? '--'}',
                      style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          height: .9),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      onTrip ? 'min' : 'km/h',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                    const Spacer(),
                    if (onTrip)
                      Text(
                        '${state!.vehicle.speedKph.round()} km/h',
                        style: TextStyle(
                            color: muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
                const Divider(height: 24),
                Row(children: [
                  Icon(
                    onTrip ? Icons.flag_rounded : Icons.assistant_navigation,
                    color: AutopilotFormat.color(apollo, scheme),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      onTrip
                          ? '${AutopilotFormat.distance(ap.remainingM)}\n'
                              '${ap.destination!.label}'
                          : AutopilotFormat.title(apollo),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ]),
                if (ap?.message != null) ...[
                  const SizedBox(height: 6),
                  Text(ap!.message!,
                      style: TextStyle(fontSize: 11, color: muted)),
                ],
                const SizedBox(height: 12),
                if (ap != null && ap.engaged)
                  Row(children: [
                    Expanded(
                      child: _PanelButton(
                        label: 'Stop',
                        color: AppColors.alert,
                        busy: apollo.isPending('stop'),
                        onPressed: () => run(apollo.stop),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _PanelButton(
                        label: 'Pull over',
                        busy: apollo.isPending('pull_over'),
                        onPressed: () => run(apollo.pullOver),
                      ),
                    ),
                  ])
                else if (onTrip)
                  Row(children: [
                    if (ap.phase != AutopilotPhase.arrived) ...[
                      Expanded(
                        child: _PanelButton(
                          label: 'Resume',
                          color: scheme.primary,
                          busy: apollo.isPending('resume'),
                          onPressed: () => run(apollo.resume),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: _PanelButton(
                        label: 'End trip',
                        busy: apollo.isPending('cancel'),
                        onPressed: () => run(apollo.cancelRoute),
                      ),
                    ),
                  ]),
                if (manual || (apollo.canDrive && !(ap?.engaged ?? false))) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: _PanelButton(
                      label: manual ? 'Hand back to Apollo' : 'Drive manually',
                      color: manual ? scheme.primary : null,
                      busy: apollo.isPending('manual'),
                      onPressed: () => run(() => apollo.setManual(!manual)),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(children: [
                  Icon(Icons.speed_rounded, size: 17, color: scheme.primary),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Cruise')),
                  _StepButton(
                    icon: Icons.remove_rounded,
                    onPressed: apollo.cruiseKph > ApolloConfig.minCruiseKph
                        ? () => apollo.setCruiseKph(apollo.cruiseKph - 5)
                        : null,
                  ),
                  SizedBox(
                    width: 56,
                    child: Text(
                      '${apollo.cruiseKph.round()} km/h',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                  _StepButton(
                    icon: Icons.add_rounded,
                    onPressed: apollo.cruiseKph < ApolloConfig.maxCruiseKph
                        ? () => apollo.setCruiseKph(apollo.cruiseKph + 5)
                        : null,
                  ),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _Glass(
            dark: dark,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (final place in places)
                  _PlaceRow(
                    place: place,
                    saved: state?.places.containsKey(place.id) ?? false,
                    dark: dark,
                    enabled: apollo.canDrive,
                    onTap: () => onGoToPlace(place),
                    onDelete: () async => apolloAction(
                      context,
                      apollo.deletePlace(place.id!),
                    ),
                  ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text(
                    'Drop a pin on the map to save a place.',
                    style: TextStyle(fontSize: 11, color: muted),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceRow extends StatelessWidget {
  const _PlaceRow({
    required this.place,
    required this.saved,
    required this.dark,
    required this.enabled,
    required this.onTap,
    required this.onDelete,
  });

  final ApolloPlace place;
  final bool saved;
  final bool dark;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = dark ? Colors.white54 : Colors.black45;
    return InkWell(
      onTap: saved && enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(children: [
          Icon(
            switch (place.id) {
              'home' => Icons.home_rounded,
              'work' => Icons.work_rounded,
              _ => Icons.place_rounded,
            },
            size: 18,
            color: scheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(place.label,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  saved
                      ? '${place.x.toStringAsFixed(0)}, ${place.y.toStringAsFixed(0)} · tap to drive'
                      : 'Not set',
                  style: TextStyle(fontSize: 11, color: muted),
                ),
              ],
            ),
          ),
          if (saved)
            IconButton(
              iconSize: 16,
              visualDensity: VisualDensity.compact,
              tooltip: 'Remove ${place.label}',
              icon: Icon(Icons.delete_outline_rounded, color: muted),
              onPressed: onDelete,
            ),
        ]),
      ),
    );
  }
}

class _PinCard extends StatelessWidget {
  const _PinCard({
    required this.pin,
    required this.dark,
    required this.canDrive,
    required this.checked,
    required this.onRoad,
    required this.simControl,
    required this.going,
    required this.onGo,
    required this.onSaveHome,
    required this.onSaveWork,
    required this.onMoveCar,
    required this.onDismiss,
  });

  final Offset pin;
  final bool dark;
  final bool canDrive;

  /// The lane check finished; [onRoad] says whether the pin is on a lane.
  final bool checked;
  final bool onRoad;
  final bool simControl;
  final bool going;
  final VoidCallback onGo;
  final VoidCallback onSaveHome;
  final VoidCallback onSaveWork;
  final VoidCallback onMoveCar;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final usable = checked && onRoad;
    final muted = dark ? Colors.white54 : Colors.black45;
    return _Glass(
      dark: dark,
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Shrinks (and truncates) first, so the buttons always fit.
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Dropped pin',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w700)),
                Text(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  !checked
                      ? 'Finding the nearest lane…'
                      : onRoad
                          ? 'On lane · x ${pin.dx.toStringAsFixed(0)}  y ${pin.dy.toStringAsFixed(0)}'
                          : 'Not on a road — tap on a lane',
                  style: TextStyle(
                    fontSize: 11,
                    color: checked && !onRoad ? AppColors.alert : muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          FilledButton.icon(
            onPressed: canDrive && usable && !going ? onGo : null,
            icon: going
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: scheme.onPrimary),
                  )
                : const Icon(Icons.near_me_rounded, size: 18),
            label: const Text('Go here'),
          ),
          const SizedBox(width: 6),
          TextButton.icon(
            onPressed: usable ? onSaveHome : null,
            icon: const Icon(Icons.home_rounded, size: 18),
            label: const Text('Home'),
          ),
          TextButton.icon(
            onPressed: usable ? onSaveWork : null,
            icon: const Icon(Icons.work_rounded, size: 18),
            label: const Text('Work'),
          ),
          if (simControl)
            TextButton.icon(
              onPressed: usable ? onMoveCar : null,
              icon: const Icon(Icons.open_with_rounded, size: 18),
              label: const Text('Move car'),
            ),
          IconButton(
            tooltip: 'Dismiss',
            onPressed: onDismiss,
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

class _PanelButton extends StatelessWidget {
  const _PanelButton({
    required this.label,
    required this.onPressed,
    this.color,
    this.busy = false,
  });

  final String label;
  final VoidCallback onPressed;
  final Color? color;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = color ?? scheme.surfaceContainerHighest;
    final foreground = color == null
        ? scheme.onSurface
        : color == scheme.primary
            ? scheme.onPrimary
            : Colors.white;
    return SizedBox(
      height: 38,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: busy ? null : onPressed,
        child: busy
            ? SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: foreground),
              )
            : Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      iconSize: 18,
      constraints: const BoxConstraints.tightFor(width: 30, height: 30),
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      icon: Icon(icon),
    );
  }
}

class _Glass extends StatelessWidget {
  const _Glass({required this.dark, required this.child, this.padding});

  final bool dark;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: dark
            ? const Color(0xE814181A)
            : Colors.white.withValues(alpha: .96),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(blurRadius: 18, color: Color(0x18000000))],
      ),
      child: child,
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
          constraints: const BoxConstraints.tightFor(width: 48, height: 48),
        ),
      ),
    );
  }
}
