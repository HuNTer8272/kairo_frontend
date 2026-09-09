import 'package:flutter/material.dart';

class SettingsContent extends StatefulWidget {
  const SettingsContent({super.key, required this.title});
  final String title;

  @override
  State<SettingsContent> createState() => _SettingsContentState();
}

class _SettingsContentState extends State<SettingsContent> {
  bool headlights = true;
  bool mirrorsFolded = false;
  bool recording = true;
  bool sentry = true;
  double brightness = .72;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title, style: const TextStyle(
            fontSize: 22, fontWeight: FontWeight.w700,
          )),
          const SizedBox(height: 18),
          SegmentedControl(
            labels: const ['Off', 'Parking', 'On', 'Auto'],
            selected: headlights ? 3 : 0,
            onTap: (index) =>
                setState(() => headlights = index != 0),
          ),
          const SizedBox(height: 18),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.18,
            children: [
              ControlTile(
                icon: Icons.flip_camera_android_rounded,
                label: 'Fold Mirrors',
                active: mirrorsFolded,
                onTap: () =>
                    setState(() => mirrorsFolded = !mirrorsFolded),
              ),
              const ControlTile(
                icon: Icons.lock_outline_rounded,
                label: 'Child Lock',
              ),
              const ControlTile(
                icon: Icons.window_rounded,
                label: 'Window Lock',
              ),
              const ControlTile(
                icon: Icons.back_hand_outlined,
                label: 'Glovebox',
              ),
              const ControlTile(
                icon: Icons.flip_camera_android_rounded,
                label: 'Mirrors',
              ),
              ControlTile(
                icon: Icons.videocam_outlined,
                label: 'Recording',
                active: recording,
                onTap: () =>
                    setState(() => recording = !recording),
              ),
              const ControlTile(
                icon: Icons.local_car_wash_outlined,
                label: 'Car Wash',
              ),
              const ControlTile(
                icon: Icons.sports_motorsports_rounded,
                label: 'Steering',
              ),
              ControlTile(
                icon: Icons.adjust_rounded,
                label: 'Sentry',
                active: sentry,
                onTap: () => setState(() => sentry = !sentry),
              ),
              const ControlTile(
                icon: Icons.headset_mic_outlined,
                label: 'Neutral Tow',
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              const Icon(Icons.brightness_low_rounded),
              Expanded(
                child: Slider(
                  value: brightness,
                  onChanged: (value) =>
                      setState(() => brightness = value),
                ),
              ),
              FilledButton(
                onPressed: () {},
                child: const Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10, vertical: 12,
                  ),
                  child: Text('Auto'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SegmentedControl extends StatelessWidget {
  const SegmentedControl({
    super.key,
    required this.labels,
    required this.selected,
    required this.onTap,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(labels.length, (index) {
        final active = selected == index;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: index == labels.length - 1 ? 0 : 8,
            ),
            child: InkWell(
              onTap: () => onTap(index),
              borderRadius: BorderRadius.circular(7),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: active
                      ? const Color(0xFF246BFD)
                      : const Color(0xFFECECEB),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  labels[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: active
                        ? Colors.white
                        : const Color(0xFF5F6265),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class ControlTile extends StatelessWidget {
  const ControlTile({
    super.key,
    required this.icon,
    required this.label,
    this.active = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? const Color(0xFFE7EEFF) : Colors.white,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: active
                  ? const Color(0xFF246BFD)
                  : const Color(0xFFE3E3E1),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: active
                    ? const Color(0xFF246BFD)
                    : const Color(0xFF55585B),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
