import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RoutingService {
  /// OpenRouteService API endpoint for driving routes.
  static const String _defaultApiKey = 'eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6IjRlMjI5ZjUzZDQxZTQyMzZiMzhhMDNhNTE4NDc0ZGQxIiwiaCI6Im11cm11cjY0In0=';

  /// Fetches a list of [LatLng] points connecting [from] to [to].
  /// Reads ORS_API_KEY from .env, environment, or falls back gracefully.
  static Future<List<LatLng>> fetchRoute({
    required LatLng from,
    required LatLng to,
    String? apiKey,
  }) async {
    final key = apiKey ??
        dotenv.env['ORS_API_KEY'] ??
        const String.fromEnvironment('ORS_API_KEY', defaultValue: _defaultApiKey);

    try {
      final url = Uri.parse(
        'https://api.openrouteservice.org/v2/directions/driving-car?api_key=$key&start=${from.longitude},${from.latitude}&end=${to.longitude},${to.latitude}',
      );

      final response = await http
          .get(url, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final features = data['features'] as List?;
        if (features != null && features.isNotEmpty) {
          final geometry = features[0]['geometry'] as Map<String, dynamic>?;
          final coords = geometry?['coordinates'] as List?;
          if (coords != null && coords.isNotEmpty) {
            return coords.map((c) {
              final lon = (c[0] as num).toDouble();
              final lat = (c[1] as num).toDouble();
              return LatLng(lat, lon);
            }).toList();
          }
        }
      }
    } catch (_) {
      // Fall through to linear fallback if network or key fails
    }

    return _generateFallbackRoute(from, to);
  }

  /// Linear interpolation fallback route (adds intermediate waypoints for smooth animation)
  static List<LatLng> _generateFallbackRoute(LatLng start, LatLng end, {int steps = 15}) {
    final points = <LatLng>[];
    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      final lat = start.latitude + (end.latitude - start.latitude) * t;
      final lng = start.longitude + (end.longitude - start.longitude) * t;
      points.add(LatLng(lat, lng));
    }
    return points;
  }
}
