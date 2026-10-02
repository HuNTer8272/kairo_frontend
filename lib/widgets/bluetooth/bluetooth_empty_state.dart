import 'package:flutter/material.dart';

/// Centered state message for the Bluetooth screen (Bluetooth off,
/// permission needed, no devices, ...). Matches the Music screen panels.
class BluetoothEmptyState extends StatelessWidget {
  const BluetoothEmptyState({
    super.key,
    this.icon,
    required this.title,
    required this.message,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.busy = false,
    this.compact = false,
  });

  final IconData? icon;
  final String title;
  final String message;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool busy;

  /// Smaller variant used inside a device list column.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final badge = compact ? 64.0 : 96.0;
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: badge,
              height: badge,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                shape: BoxShape.circle,
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: busy
                  ? Padding(
                      padding: EdgeInsets.all(badge * 0.35),
                      child: const CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : Icon(icon, size: badge * 0.44, color: scheme.primary),
            ),
            SizedBox(height: compact ? 14 : 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: compact ? 17 : 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: compact ? 13 : 14,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            if (primaryLabel != null || secondaryLabel != null) ...[
              SizedBox(height: compact ? 16 : 24),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  if (primaryLabel != null)
                    FilledButton(
                      onPressed: onPrimary,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 12,
                        ),
                        child: Text(primaryLabel!),
                      ),
                    ),
                  if (secondaryLabel != null)
                    TextButton(
                      onPressed: onSecondary,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(secondaryLabel!),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
