import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remembers the last few destinations typed into the navigation search
/// bar, most recent first. KAIRO has no trip history of its own — this is
/// just a short local memory of what the driver searched for.
class RecentDestinationsService extends ChangeNotifier {
  RecentDestinationsService({@visibleForTesting SharedPreferences? prefs})
      : _prefs = prefs;

  static const _storageKey = 'recent_destinations';
  static const maxEntries = 5;

  SharedPreferences? _prefs;
  List<String> _recents = [];

  List<String> get recents => List.unmodifiable(_recents);

  Future<void> load() async {
    _prefs ??= await SharedPreferences.getInstance();
    _recents = _prefs!.getStringList(_storageKey) ?? [];
    notifyListeners();
  }

  Future<void> add(String destination) async {
    final trimmed = destination.trim();
    if (trimmed.isEmpty) return;
    _prefs ??= await SharedPreferences.getInstance();
    _recents.removeWhere((e) => e.toLowerCase() == trimmed.toLowerCase());
    _recents.insert(0, trimmed);
    if (_recents.length > maxEntries) {
      _recents = _recents.sublist(0, maxEntries);
    }
    await _prefs!.setStringList(_storageKey, _recents);
    notifyListeners();
  }

  Future<void> clear() async {
    _prefs ??= await SharedPreferences.getInstance();
    _recents = [];
    await _prefs!.remove(_storageKey);
    notifyListeners();
  }
}
