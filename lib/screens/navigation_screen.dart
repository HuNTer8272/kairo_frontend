import 'package:flutter/material.dart';

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key, this.onClose});

  final VoidCallback? onClose;

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  bool rearView = false;
  bool satellite = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final darkMap = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: scheme.surface,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _MapPainter(
                dark: darkMap,
                rearView: rearView,
                accent: scheme.primary,
              ),
            ),
          ),
          Positioned(
            left: 20,
            top: 20,
            width: 224,
            child: _DrivePanel(
              rearView: rearView,
              dark: darkMap,
              onToggle: () => setState(() => rearView = !rearView),
            ),
          ),
          Positioned(
            top: 20,
            left: 250,
            right: 24,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: darkMap ? const Color(0xD91B2022) : Colors.white.withValues(alpha: .94),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [BoxShadow(blurRadius: 18, color: Color(0x18000000))],
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search_rounded, color: scheme.primary),
                        const SizedBox(width: 10),
                        Text(rearView ? 'Rear map view' : 'Navigate', style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _MapButton(
                  icon: satellite ? Icons.layers_rounded : Icons.map_outlined,
                  tooltip: 'Map layers',
                  onPressed: () => setState(() => satellite = !satellite),
                ),
                const SizedBox(width: 8),
                _MapButton(icon: Icons.close_rounded, tooltip: 'Close map', onPressed: widget.onClose),
              ],
            ),
          ),
          Positioned(
            right: 24,
            bottom: 24,
            child: Column(
              children: [
                _MapButton(icon: Icons.add_rounded, tooltip: 'Zoom in', onPressed: () {}),
                const SizedBox(height: 2),
                _MapButton(icon: Icons.remove_rounded, tooltip: 'Zoom out', onPressed: () {}),
                const SizedBox(height: 10),
                _MapButton(icon: Icons.my_location_rounded, tooltip: 'Center vehicle', onPressed: () {}),
              ],
            ),
          ),
          Positioned(
            left: 270,
            bottom: 26,
            child: Text(
              satellite ? 'Satellite map' : 'Standard map  |  500 m',
              style: TextStyle(color: darkMap ? Colors.white70 : const Color(0xFF4D565A), fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _DrivePanel extends StatelessWidget {
  const _DrivePanel({required this.rearView, required this.dark, required this.onToggle});

  final bool rearView;
  final bool dark;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final background = dark ? const Color(0xE814181A) : Colors.white.withValues(alpha: .96);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(8), boxShadow: const [BoxShadow(blurRadius: 18, color: Color(0x18000000))]),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [const Text('NAVIGATION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.3)), const Spacer(), Icon(Icons.more_horiz_rounded, size: 18, color: Theme.of(context).colorScheme.primary)]),
              const SizedBox(height: 12),
              Text(rearView ? 'Rear camera map' : '29', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700, height: .9)),
              Text(rearView ? 'Vehicle position' : 'min', style: TextStyle(color: dark ? Colors.white60 : Colors.black54, fontSize: 12)),
              const Divider(height: 24),
              Row(children: [Icon(Icons.turn_right_rounded, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 8), const Expanded(child: Text('200 ft\nSan Francisco Street', style: TextStyle(fontWeight: FontWeight.w600)))]),
              const SizedBox(height: 14),
              Row(children: [Icon(rearView ? Icons.camera_rear_rounded : Icons.navigation_rounded, size: 17, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 8), Expanded(child: Text(rearView ? 'Rear view' : 'Drive view')), Switch.adaptive(value: rearView, onChanged: (_) => onToggle())]),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(8)),
          child: Row(children: [Icon(Icons.home_rounded, size: 18, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 8), const Expanded(child: Text('Home', style: TextStyle(fontWeight: FontWeight.w600))), Icon(Icons.chevron_right_rounded, color: dark ? Colors.white54 : Colors.black45)]),
        ),
      ],
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Theme.of(context).brightness == Brightness.dark ? const Color(0xE81B2022) : Colors.white.withValues(alpha: .96),
        borderRadius: BorderRadius.circular(8),
        child: IconButton(onPressed: onPressed, icon: Icon(icon), constraints: const BoxConstraints.tightFor(width: 48, height: 48)),
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  const _MapPainter({required this.dark, required this.rearView, required this.accent});

  final bool dark;
  final bool rearView;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()..color = dark ? const Color(0xFF24292B) : const Color(0xFFE8ECE9);
    canvas.drawRect(Offset.zero & size, background);
    final road = Paint()..color = dark ? const Color(0xFF343A3C) : const Color(0xFFFFFFFF)..strokeWidth = 1;
    final major = Paint()..color = dark ? const Color(0xFF4B5355) : const Color(0xFFD1D8D4)..strokeWidth = 2;
    for (var i = -size.height.toInt(); i < size.width.toInt() + size.height.toInt(); i += 58) {
      canvas.drawLine(Offset(i.toDouble(), 0), Offset(i + size.height, size.height), road);
      canvas.drawLine(Offset(i.toDouble(), size.height), Offset(i + size.height, 0), road);
    }
    for (var i = 40.0; i < size.width; i += 180) {
      canvas.drawLine(Offset(i, 0), Offset(i - 90, size.height), major);
    }
    final route = Paint()..color = const Color(0xFFF3B51B)..strokeWidth = 5..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final routePath = Path()..moveTo(size.width * .22, size.height * .86)..lineTo(size.width * .37, size.height * .65)..lineTo(size.width * .52, size.height * .52)..lineTo(size.width * .67, size.height * .30)..lineTo(size.width * .92, size.height * .14);
    canvas.drawPath(routePath, route);
    final vehicle = Offset(size.width * .53, size.height * .52);
    canvas.drawCircle(vehicle, 18, Paint()..color = accent.withValues(alpha: .16));
    canvas.drawCircle(vehicle, 7, Paint()..color = accent);
    if (rearView) {
      final camera = Paint()..color = const Color(0xFFEF5B5B)..style = PaintingStyle.stroke..strokeWidth = 3;
      canvas.drawArc(Rect.fromCircle(center: vehicle, radius: 34), 0.35, 2.45, false, camera);
    }
  }

  @override
  bool shouldRepaint(covariant _MapPainter oldDelegate) => oldDelegate.dark != dark || oldDelegate.rearView != rearView || oldDelegate.accent != accent;
}
