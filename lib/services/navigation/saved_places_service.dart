import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A single quick-access destination. Home and Work (ids `home`/`work`)
/// always exist and can't be deleted — only renamed and have their
/// address set or cleared. Any other place is freely added and removed.
class SavedPlace {
  const SavedPlace({required this.id, required this.label, this.address});

  final String id;
  final String label;
  final String? address;

  bool get isDefault => id == 'home' || id == 'work';

  SavedPlace copyWith({
    String? label,
    String? address,
    bool clearAddress = false,
  }) {
    return SavedPlace(
      id: id,
      label: label ?? this.label,
      address: clearAddress ? null : (address ?? this.address),
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'label': label, 'address': address};

  factory SavedPlace.fromJson(Map<String, dynamic> json) => SavedPlace(
        id: json['id'] as String,
        label: json['label'] as String,
        address: json['address'] as String?,
      );
}

/// Persists the driver's saved places across launches.
///
/// Addresses are free-text strings (street address, place name, or a
/// geocoded suggestion) handed directly to the device's own maps app —
/// KAIRO never geocodes the final destination itself, only suggests
/// candidates while typing (see [GeocodingService]).
class SavedPlacesService extends ChangeNotifier {
  SavedPlacesService({@visibleForTesting SharedPreferences? prefs})
      : _prefs = prefs;

  static const _storageKey = 'saved_places_v2';

  SharedPreferences? _prefs;
  List<SavedPlace> _places = const [
    SavedPlace(id: 'home', label: 'Home'),
    SavedPlace(id: 'work', label: 'Work'),
  ];

  List<SavedPlace> get places => List.unmodifiable(_places);

  SavedPlace? byId(String id) {
    for (final place in _places) {
      if (place.id == id) return place;
    }
    return null;
  }

  String? addressFor(String id) => byId(id)?.address;

  Future<void> load() async {
    _prefs ??= await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_storageKey);
    if (raw != null) {
      try {
        final decoded = (jsonDecode(raw) as List)
            .map((e) => SavedPlace.fromJson(e as Map<String, dynamic>))
            .toList();
        if (decoded.isNotEmpty) _places = decoded;
      } catch (_) {
        // Corrupt or outdated data — keep the defaults.
      }
    }
    notifyListeners();
  }

  Future<void> addPlace(String label) async {
    final trimmed = label.trim();
    if (trimmed.isEmpty) return;
    final id = 'place_${DateTime.now().microsecondsSinceEpoch}';
    _places = [..._places, SavedPlace(id: id, label: trimmed)];
    notifyListeners();
    await _persist();
  }

  Future<void> rename(String id, String label) async {
    final trimmed = label.trim();
    if (trimmed.isEmpty) return;
    _replace(id, (place) => place.copyWith(label: trimmed));
    await _persist();
  }

  Future<void> setAddress(String id, String address) async {
    final trimmed = address.trim();
    _replace(
      id,
      (place) => trimmed.isEmpty
          ? place.copyWith(clearAddress: true)
          : place.copyWith(address: trimmed),
    );
    await _persist();
  }

  Future<void> remove(String id) async {
    final place = byId(id);
    if (place == null || place.isDefault) return;
    _places = _places.where((p) => p.id != id).toList();
    notifyListeners();
    await _persist();
  }

  void _replace(String id, SavedPlace Function(SavedPlace) update) {
    _places = [for (final p in _places) if (p.id == id) update(p) else p];
    notifyListeners();
  }

  Future<void> _persist() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(
      _storageKey,
      jsonEncode(_places.map((p) => p.toJson()).toList()),
    );
  }
}
