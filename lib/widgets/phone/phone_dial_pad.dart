import 'package:flutter/material.dart';

import '../../services/phone/phone_call_launcher.dart';

/// Right panel: a numeric keypad that opens the phone's own dialer app
/// with the entered number pre-filled (an Android `tel:` view intent).
///
/// This does not place a call itself. KAIRO has no way to place or
/// control calls directly (see PhoneIdlePanel) — this is the one real,
/// honest action available without deeper Android system integration.
class PhoneDialPad extends StatefulWidget {
  const PhoneDialPad({super.key, this.launcher = const PhoneCallLauncher()});

  final PhoneCallLauncher launcher;

  @override
  State<PhoneDialPad> createState() => _PhoneDialPadState();
}

class _PhoneDialPadState extends State<PhoneDialPad> {
  String _digits = '';
  String? _error;

  static const _keys = [
    ['1', ''],
    ['2', 'ABC'],
    ['3', 'DEF'],
    ['4', 'GHI'],
    ['5', 'JKL'],
    ['6', 'MNO'],
    ['7', 'PQRS'],
    ['8', 'TUV'],
    ['9', 'WXYZ'],
    ['*', ''],
    ['0', '+'],
    ['#', ''],
  ];

  void _press(String digit) => setState(() {
        _error = null;
        _digits += digit;
      });

  void _backspace() => setState(() {
        _error = null;
        if (_digits.isNotEmpty) {
          _digits = _digits.substring(0, _digits.length - 1);
        }
      });

  void _clear() => setState(() {
        _error = null;
        _digits = '';
      });

  Future<void> _call() async {
    if (_digits.isEmpty) return;
    final opened = await widget.launcher.dial(_digits);
    if (!opened && mounted) {
      setState(() => _error = 'No dialer app available on this device');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        SizedBox(
          height: 44,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _digits.isEmpty ? 'Enter a number' : _digits,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: _digits.isEmpty
                        ? scheme.onSurfaceVariant
                        : scheme.onSurface,
                  ),
                ),
              ),
              if (_digits.isNotEmpty)
                IconButton(
                  onPressed: _backspace,
                  onLongPress: _clear,
                  tooltip: 'Backspace (hold to clear)',
                  icon: const Icon(Icons.backspace_outlined),
                ),
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _error!,
              style: TextStyle(fontSize: 12, color: scheme.error),
            ),
          ),
        Expanded(
          child: GridView.count(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.5,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final entry in _keys)
                _DialKey(entry[0], entry[1], onTap: _press),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: 64,
          height: 64,
          child: FilledButton(
            onPressed: _digits.isEmpty ? null : _call,
            style: FilledButton.styleFrom(
              shape: const CircleBorder(),
              padding: EdgeInsets.zero,
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
            ),
            child: const Icon(Icons.call_rounded, size: 26),
          ),
        ),
      ],
    );
  }
}

class _DialKey extends StatelessWidget {
  const _DialKey(this.digit, this.letters, {required this.onTap});

  final String digit;
  final String letters;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => onTap(digit),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                digit,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              if (letters.isNotEmpty)
                Text(
                  letters,
                  style:
                      TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
