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

  static Future<List<Map<String, dynamic>>> searchAddress(String query, {int limit = 5}) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(query)}&addressdetails=1&limit=$limit',
      );
      final response = await http.get(url, headers: {'User-Agent': _userAgent});
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body) as List<dynamic>;
        return data
            .whereType<Map<String, dynamic>>()
            .map((item) => {
                  'display': (item['display_name'] ?? '').toString(),
                  'lat': double.tryParse(item['lat']?.toString() ?? ''),
                  'lng': double.tryParse(item['lon']?.toString() ?? ''),
                })
            .where((item) => (item['display'] as String).isNotEmpty)
            .toList();
      }
    } catch (_) {}
    return const [];
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
