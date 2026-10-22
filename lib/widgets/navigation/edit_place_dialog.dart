import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/navigation/geocoding_service.dart';
import '../../services/navigation/saved_places_service.dart';

/// Result of [showEditPlaceDialog]: a label/address to save, or a request
/// to delete the place entirely (only possible for non-default places).
class EditPlaceResult {
  const EditPlaceResult.save({required this.label, required this.address})
      : delete = false;
  const EditPlaceResult.delete()
      : label = '',
        address = '',
        delete = true;

  final String label;
  final String address;
  final bool delete;
}

/// A Google Maps "edit label" style sheet: a round icon, an editable
/// name, an address field with live suggestions as you type, and a clear
/// separation between the destructive action and the confirming ones.
Future<EditPlaceResult?> showEditPlaceDialog(
  BuildContext context, {
  required SavedPlace place,
  GeocodingService geocoder = const GeocodingService(),
}) {
  return showDialog<EditPlaceResult>(
    context: context,
    builder: (context) =>
        _EditPlaceDialog(place: place, geocoder: geocoder),
  );
}

class _EditPlaceDialog extends StatefulWidget {
  const _EditPlaceDialog({required this.place, required this.geocoder});

  final SavedPlace place;
  final GeocodingService geocoder;

  @override
  State<_EditPlaceDialog> createState() => _EditPlaceDialogState();
}

class _EditPlaceDialogState extends State<_EditPlaceDialog> {
  late final _labelController = TextEditingController(text: widget.place.label);
  late final _addressController =
      TextEditingController(text: widget.place.address);
  Timer? _debounce;
  List<PlaceSuggestion> _suggestions = [];

  @override
  void dispose() {
    _debounce?.cancel();
    _labelController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _onAddressChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 3) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final results = await widget.geocoder.suggest(value);
      if (mounted) setState(() => _suggestions = results);
    });
  }

  void _pickSuggestion(String label) {
    setState(() {
      _addressController.text = label;
      _suggestions = [];
    });
  }

  void _save() {
    Navigator.pop(
      context,
      EditPlaceResult.save(
        label: _labelController.text,
        address: _addressController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final icon = switch (widget.place.id) {
      'home' => Icons.home_rounded,
      'work' => Icons.work_rounded,
      _ => Icons.place_rounded,
    };

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 520),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: scheme.primary.withValues(alpha: .14),
                child: Icon(icon, color: scheme.primary, size: 26),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _labelController,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Name',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _addressController,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onChanged: _onAddressChanged,
                onSubmitted: (_) => _save(),
                decoration: const InputDecoration(
                  labelText: 'Address or place name',
                  border: UnderlineInputBorder(),
                ),
              ),
              if (_suggestions.isNotEmpty)
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(top: 4),
                    children: [
                      for (final suggestion in _suggestions)
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.location_on_outlined,
                              size: 20),
                          title: Text(
                            suggestion.label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                          onTap: () => _pickSuggestion(suggestion.label),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (!widget.place.isDefault)
                    TextButton(
                      onPressed: () => Navigator.pop(
                          context, const EditPlaceResult.delete()),
                      style: TextButton.styleFrom(foregroundColor: scheme.error),
                      child: const Text('Delete'),
                    )
                  else if (widget.place.address != null)
                    TextButton(
                      onPressed: () => Navigator.pop(
                          context,
                          EditPlaceResult.save(
                              label: _labelController.text, address: '')),
                      style: TextButton.styleFrom(foregroundColor: scheme.error),
                      child: const Text('Clear address'),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 4),
                  FilledButton(
                    onPressed: _save,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
