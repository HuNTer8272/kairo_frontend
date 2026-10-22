import 'package:flutter/material.dart';

/// Left panel placeholder.
///
/// KAIRO has no access to call history or contacts — that needs the
/// phone's own call log/contacts (READ_CALL_LOG / READ_CONTACTS) plus a
/// real Telecom/HFP link, neither of which exists yet. Shown honestly
/// instead of fabricated entries.
class PhoneRecentsPanel extends StatelessWidget {
  const PhoneRecentsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RECENTS',
          style: TextStyle(
            fontSize: 12,
            letterSpacing: 1.1,
            fontWeight: FontWeight.w700,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outlineVariant),
            ),
            alignment: Alignment.topLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.history_rounded, color: scheme.onSurfaceVariant),
                const SizedBox(height: 10),
                const Text(
                  'Call history is not available yet.',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  'Reading recent and missed calls needs direct access to '
                  'your phone\'s call log, which KAIRO does not yet have.',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
