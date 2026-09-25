import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class GeocodingHelper {
  static const _userAgent = 'SahyogApp/1.0 (food-donation)';

  static Future<String> reverseGeocode(double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&addressdetails=1',
      );
      final response = await http.get(url, headers: {'User-Agent': _userAgent});
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final displayName = (data['display_name'] as String?)?.trim();
        if (displayName != null && displayName.isNotEmpty) return displayName;
      }
    } catch (_) {}
    return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
  }

  static const Map<String, LatLng> _knownCityPlaces = {
    'mumbai': LatLng(19.0760, 72.8777),
    'bandra': LatLng(19.0596, 72.8295),
    'andheri': LatLng(19.1136, 72.8697),
    'colaba': LatLng(18.9067, 72.8147),
    'dadar': LatLng(19.0178, 72.8478),
    'powai': LatLng(19.1176, 72.9060),
    'juhu': LatLng(19.1006, 72.8268),
    'worli': LatLng(19.0117, 72.8180),
    'chembur': LatLng(19.0622, 72.8974),
    'borivali': LatLng(19.2307, 72.8567),
    'thane': LatLng(19.2183, 72.9781),
    'navi mumbai': LatLng(19.0330, 73.0297),
    'pune': LatLng(18.5204, 73.8567),
    'nagpur': LatLng(21.1458, 79.0882),
    'wardha': LatLng(20.7453, 78.6022),
    'samudrapur': LatLng(20.6053, 79.0394),
    'delhi': LatLng(28.6139, 77.2090),
    'bangalore': LatLng(12.9716, 77.5946),
    'bengaluru': LatLng(12.9716, 77.5946),
    'hyderabad': LatLng(17.3850, 78.4867),
    'chennai': LatLng(13.0827, 80.2707),
    'kolkata': LatLng(22.5726, 88.3639),
    'ahmedabad': LatLng(23.0225, 72.5714),
  };

  static Future<List<Map<String, dynamic>>> searchAddress(String query, {int limit = 8}) async {
    final results = <Map<String, dynamic>>[];
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return results;
    final encodedQuery = Uri.encodeComponent(cleanQuery);

    // 1. Try Nominatim Search API (6s timeout)
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?format=json&q=$encodedQuery&addressdetails=1&limit=$limit&countrycodes=in',
      );
      final response = await http.get(url, headers: {'User-Agent': _userAgent}).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body) as List<dynamic>;
        for (final item in data.whereType<Map<String, dynamic>>()) {
          final display = (item['display_name'] ?? '').toString();
          final lat = double.tryParse(item['lat']?.toString() ?? '');
          final lng = double.tryParse(item['lon']?.toString() ?? '');
          if (display.isNotEmpty && lat != null && lng != null) {
            results.add({
              'display': display,
              'lat': lat,
              'lng': lng,
              'title': item['name']?.toString() ?? display.split(',').first,
            });
          }
        }
      }
    } catch (_) {}

    // 2. Fallback to global search if country-restricted returned empty
    if (results.isEmpty) {
      try {
        final url = Uri.parse(
          'https://nominatim.openstreetmap.org/search?format=json&q=$encodedQuery&addressdetails=1&limit=$limit',
        );
        final response = await http.get(url, headers: {'User-Agent': _userAgent}).timeout(const Duration(seconds: 6));
        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body) as List<dynamic>;
          for (final item in data.whereType<Map<String, dynamic>>()) {
            final display = (item['display_name'] ?? '').toString();
            final lat = double.tryParse(item['lat']?.toString() ?? '');
            final lng = double.tryParse(item['lon']?.toString() ?? '');
            if (display.isNotEmpty && lat != null && lng != null) {
              results.add({
                'display': display,
                'lat': lat,
                'lng': lng,
                'title': item['name']?.toString() ?? display.split(',').first,
              });
            }
          }
        }
      } catch (_) {}
    }

    // 3. Fallback to known offline locations if API failed or returned empty
    if (results.isEmpty) {
      final qLower = cleanQuery.toLowerCase();
      for (final entry in _knownCityPlaces.entries) {
        if (qLower.contains(entry.key) || entry.key.contains(qLower)) {
          final titleStr = entry.key[0].toUpperCase() + entry.key.substring(1);
          results.add({
            'display': '$titleStr, India',
            'lat': entry.value.latitude,
            'lng': entry.value.longitude,
            'title': titleStr,
          });
        }
      }
    }

    return results;
  }

  static Future<MapLocationResult?> resolveAddress(String query) async {
    final results = await searchAddress(query, limit: 1);
    if (results.isEmpty) return null;
    final item = results.first;
    final lat = item['lat'] as double?;
    final lng = item['lng'] as double?;
    final display = item['display'] as String? ?? query;
    if (lat == null || lng == null) return null;
    return MapLocationResult(address: display, latitude: lat, longitude: lng);
  }
}

class MapLocationResult {
  final String address;
  final double latitude;
  final double longitude;

  const MapLocationResult({
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  LatLng get latLng => LatLng(latitude, longitude);
}
