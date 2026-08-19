import 'dart:convert';
import 'package:http/http.dart' as http;

class LocationService {
  /// Fetches a detailed, human-readable place name address with pincode from lat & lng coordinates.
  static Future<String?> getAddressFromCoordinates(double lat, double lng) async {
    // Tier 1: OpenStreetMap Nominatim API with detailed address structure & postcode
    try {
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lng&zoom=18&addressdetails=1');
      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'SahyogApp/2.0 (FoodDonationPlatform; contact@sahyog.org)',
          'Accept-Language': 'en-US,en;q=0.9',
        },
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final addr = data['address'] as Map<String, dynamic>?;
        final displayName = data['display_name'] as String?;

        if (addr != null && addr.isNotEmpty) {
          final parts = <String>[];

          // 1. House Number / Building / Venue / Landmark / Shop / Office
          final houseNo = addr['house_number'];
          final venue = addr['amenity'] ??
              addr['building'] ??
              addr['shop'] ??
              addr['office'] ??
              addr['tourism'] ??
              addr['historic'] ??
              addr['leisure'] ??
              addr['place'] ??
              addr['landmark'];

          if (houseNo != null && houseNo.toString().isNotEmpty) {
            if (venue != null && venue.toString().isNotEmpty) {
              parts.add('${venue.toString()} (#${houseNo.toString()})');
            } else {
              parts.add('#${houseNo.toString()}');
            }
          } else if (venue != null && venue.toString().isNotEmpty) {
            parts.add(venue.toString());
          }

          // 2. Road / Street
          final road = addr['road'] ?? addr['pedestrian'] ?? addr['street'];
          if (road != null && road.toString().isNotEmpty && !parts.contains(road.toString())) {
            parts.add(road.toString());
          }

          // 3. Suburb / Area / Locality / Neighbourhood
          final suburb = addr['suburb'] ??
              addr['neighbourhood'] ??
              addr['residential'] ??
              addr['quarter'] ??
              addr['subdistrict'];
          if (suburb != null && suburb.toString().isNotEmpty && !parts.contains(suburb.toString())) {
            parts.add(suburb.toString());
          }

          // 4. City / Town / Village / Locality
          final city = addr['city'] ??
              addr['town'] ??
              addr['village'] ??
              addr['municipality'] ??
              addr['city_district'] ??
              addr['county'];
          if (city != null && city.toString().isNotEmpty && !parts.contains(city.toString())) {
            parts.add(city.toString());
          }

          // 5. State
          final state = addr['state'] ?? addr['state_district'];
          if (state != null && state.toString().isNotEmpty && !parts.contains(state.toString())) {
            parts.add(state.toString());
          }

          // 6. Pincode / Postcode
          final postcode = addr['postcode'] ?? addr['postal_code'];
          if (postcode != null && postcode.toString().isNotEmpty) {
            parts.add('PIN: ${postcode.toString()}');
          }

          if (parts.isNotEmpty) {
            return parts.join(', ');
          }
        }

        if (displayName != null && displayName.isNotEmpty) {
          return displayName;
        }
      }
    } catch (_) {
      // Nominatim failed or timed out, fall through to Tier 2
    }

    // Tier 2: BigDataCloud Reverse Geocoding API (Fast, Reliable, Free fallback)
    try {
      final fallbackUrl = Uri.parse(
          'https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=$lat&longitude=$lng&localityLanguage=en');
      final response = await http.get(fallbackUrl).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final parts = <String>[];

        final locality = data['locality'] as String?;
        final city = data['city'] as String?;
        final state = data['principalSubdivision'] as String?;
        final postcode = data['postcode'] as String?;

        if (locality != null && locality.isNotEmpty) parts.add(locality);
        if (city != null && city.isNotEmpty && !parts.contains(city)) parts.add(city);
        if (state != null && state.isNotEmpty && !parts.contains(state)) parts.add(state);
        if (postcode != null && postcode.isNotEmpty) parts.add('PIN: $postcode');

        if (parts.isNotEmpty) {
          return parts.join(', ');
        }
      }
    } catch (_) {
      // Network or parsing error
    }

    return null;
  }

  /// Sanitizes an address string to strip out raw coordinates like "Location Pin (12.3456, 78.9012)"
  /// or "Lat: 12.34, Lng: 56.78" and replace them with a clean location place name.
  static String cleanAddress(String? rawAddress, {String fallbackName = 'Official Registered Location'}) {
    if (rawAddress == null || rawAddress.trim().isEmpty) {
      return fallbackName;
    }

    String address = rawAddress.trim();

    // Match patterns like "Location Pin (12.3456, 78.9012)", "Lat: 12.34, Lng: 56.78", or raw "(12.34, 56.78)"
    final coordOnlyRegex = RegExp(
      r'^(Location Pin|Pinned Location|Lat|Latitude|Location|Pin)?\s*\(?\s*[-+]?\d{1,3}\.\d+[\s,]+[-+]?\d{1,3}\.\d+\s*\)?$',
      caseSensitive: false,
    );

    final containsLatLongRegex = RegExp(
      r'\(?\s*[-+]?\d{1,3}\.\d{3,}[\s,]+[-+]?\d{1,3}\.\d{3,}\s*\)?',
    );

    if (coordOnlyRegex.hasMatch(address)) {
      return fallbackName;
    }

    if (containsLatLongRegex.hasMatch(address)) {
      address = address.replaceAll(containsLatLongRegex, '').trim();
      if (address.endsWith(',')) {
        address = address.substring(0, address.length - 1).trim();
      }
      if (address.isEmpty) {
        return fallbackName;
      }
    }

    return address;
  }
}
