import 'dart:convert';
import 'package:http/http.dart' as http;

/// One address/place suggestion returned while the driver is typing.
class PlaceSuggestion {
  const PlaceSuggestion(this.label);
  final String label;
}

/// Looks up address suggestions as the driver types, using OpenStreetMap's
/// free Nominatim search — the same data source already backing the map
/// tiles, so this doesn't introduce a separate provider or API key.
class GeocodingService {
  const GeocodingService();

  // Mumbai Metropolitan Region bounding box (lon/lat), used to keep
  // suggestions local — KAIRO's demo route lives in Mumbai, so results
  // from elsewhere aren't useful here.
  static const _mumbaiViewbox = '72.70,19.35,73.15,18.85';

  Future<List<PlaceSuggestion>> suggest(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 3) return const [];
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': trimmed,
      'format': 'jsonv2',
      'limit': '5',
      'countrycodes': 'in',
      'viewbox': _mumbaiViewbox,
      'bounded': '1',
    });
    try {
      final response = await http
          .get(uri, headers: {'User-Agent': 'KAIRO-VehicleTabletUI/1.0'})
          .timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return const [];
      final results = jsonDecode(response.body) as List;
      return [
        for (final entry in results)
          PlaceSuggestion(entry['display_name'] as String),
      ];
    } catch (_) {
      return const [];
    }
  }
}
