import 'package:flutter/material.dart';

/// Four signal bars derived from a measured RSSI (dBm). Renders nothing
/// when no RSSI has been measured.
class BluetoothSignalIndicator extends StatelessWidget {
  const BluetoothSignalIndicator({
    super.key,
    required this.rssi,
    this.showValue = true,
  });

  final int? rssi;
  final bool showValue;

  static int barsFor(int rssi) {
    if (rssi >= -60) return 4;
    if (rssi >= -70) return 3;
    if (rssi >= -80) return 2;
    if (rssi >= -90) return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final value = rssi;
    if (value == null || value == 0) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final bars = barsFor(value);

    return Tooltip(
      message: 'Signal $value dBm',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < 4; i++) ...[
            Container(
              width: 3,
              height: 5.0 + i * 3,
              decoration: BoxDecoration(
                color: i < bars ? scheme.primary : scheme.outlineVariant,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            if (i < 3) const SizedBox(width: 2),
          ],
          if (showValue) ...[
            const SizedBox(width: 6),
            Text(
              '$value dBm',
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}
