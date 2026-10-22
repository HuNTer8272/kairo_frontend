import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/navigation/geocoding_service.dart';
import '../../services/navigation/saved_places_service.dart';

/// A Google Maps-style search experience: tapping the search bar expands
/// it into a panel with a focused text field, live address suggestions as
/// you type, and (while empty) saved places and recent destinations to
/// jump back into — instead of a plain dialog.
class NavigationSearchPanel extends StatefulWidget {
  const NavigationSearchPanel({
    super.key,
    required this.places,
    required this.recents,
    required this.onSubmit,
    required this.onClose,
    this.geocoder = const GeocodingService(),
  });

  final SavedPlacesService places;
  final List<String> recents;
  final ValueChanged<String> onSubmit;
  final VoidCallback onClose;
  final GeocodingService geocoder;

  @override
  State<NavigationSearchPanel> createState() => _NavigationSearchPanelState();
}

class _NavigationSearchPanelState extends State<NavigationSearchPanel> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  List<PlaceSuggestion> _suggestions = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit(String value) {
    if (value.trim().isEmpty) return;
    widget.onSubmit(value.trim());
  }

  void _onChanged(String value) {
    setState(() {});
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final query = _controller.text.trim();
    final savedWithAddress =
        widget.places.places.where((p) => p.address != null).toList();

    return Material(
      color: dark ? const Color(0xF21B2022) : Colors.white.withValues(alpha: .98),
      borderRadius: BorderRadius.circular(16),
      elevation: 12,
      shadowColor: Colors.black38,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      textInputAction: TextInputAction.search,
                      onSubmitted: _submit,
                      onChanged: _onChanged,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Search destination or address',
                      ),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ),
                  if (query.isNotEmpty)
                    IconButton(
                      onPressed: () => setState(() {
                        _controller.clear();
                        _suggestions = [];
                      }),
                      icon: const Icon(Icons.close_rounded),
                      iconSize: 20,
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 6),
                shrinkWrap: true,
                children: [
                  if (query.isNotEmpty) ...[
                    _SuggestionTile(
                      icon: Icons.search_rounded,
                      iconBackground: scheme.primary,
                      iconColor: scheme.onPrimary,
                      title: query,
                      subtitle: 'Navigate to this destination',
                      onTap: () => _submit(query),
                    ),
                    for (final suggestion in _suggestions)
                      _SuggestionTile(
                        icon: Icons.location_on_outlined,
                        iconBackground: dark
                            ? const Color(0xFF30363A)
                            : const Color(0xFFEDEDE8),
                        iconColor: dark ? Colors.white70 : Colors.black87,
                        title: suggestion.label,
                        onTap: () => _submit(suggestion.label),
                      ),
                  ] else ...[
                    if (savedWithAddress.isNotEmpty) ...[
                      const _SectionLabel('SAVED PLACES'),
                      for (final place in savedWithAddress)
                        _SuggestionTile(
                          icon: switch (place.id) {
                            'home' => Icons.home_rounded,
                            'work' => Icons.work_rounded,
                            _ => Icons.place_rounded,
                          },
                          iconBackground: dark
                              ? const Color(0xFF30363A)
                              : const Color(0xFFEDEDE8),
                          iconColor: dark ? Colors.white70 : Colors.black87,
                          title: place.label,
                          subtitle: place.address!,
                          onTap: () => _submit(place.address!),
                        ),
                    ],
                    if (widget.recents.isNotEmpty) ...[
                      const _SectionLabel('RECENT'),
                      for (final destination in widget.recents)
                        _SuggestionTile(
                          icon: Icons.history_rounded,
                          iconBackground: dark
                              ? const Color(0xFF30363A)
                              : const Color(0xFFEDEDE8),
                          iconColor: dark ? Colors.white70 : Colors.black87,
                          title: destination,
                          onTap: () => _submit(destination),
                        ),
                    ],
                    if (savedWithAddress.isEmpty && widget.recents.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 24),
                        child: Text(
                          'Search for an address, or save Home and Work from '
                          'the panel on the left for one-tap navigation.',
                          style: TextStyle(
                            fontSize: 13,
                            color: dark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
          color: dark ? Colors.white54 : Colors.black45,
        ),
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: iconBackground,
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}
