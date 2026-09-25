import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Real-time location tracking service that streams volunteer GPS coordinates
/// to Firestore (`donations/{donationId}`) during active deliveries.
class LocationTrackingService {
  static StreamSubscription<Position>? _positionStreamSub;
  static String? _activeDonationId;

  /// Returns true if currently tracking a delivery.
  static bool get isTracking => _positionStreamSub != null;

  /// Returns the current active tracked donation ID.
  static String? get activeDonationId => _activeDonationId;

  /// Starts streaming high-accuracy GPS position updates to Firestore.
  /// Distance filter is set to 10 meters to balance accuracy and battery usage.
  static Future<bool> startTracking(String donationId) async {
    if (donationId.isEmpty) return false;

    // Avoid double subscription for the same donation
    if (_activeDonationId == donationId && _positionStreamSub != null) {
      return true;
    }

    // Stop any existing tracking first
    await stopTracking();

    // Check location service & permissions
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('[LocationTrackingService] Location services are disabled.');
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('[LocationTrackingService] Location permission denied.');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('[LocationTrackingService] Location permissions permanently denied.');
      return false;
    }

    _activeDonationId = donationId;

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    try {
      _positionStreamSub = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) async {
          debugPrint(
              '[LocationTrackingService] Lat: ${position.latitude}, Lng: ${position.longitude}');

          try {
            await FirebaseFirestore.instance
                .collection('donations')
                .doc(donationId)
                .update({
              'driverLatitude': position.latitude,
              'driverLongitude': position.longitude,
              'driverLat': position.latitude,
              'driverLng': position.longitude,
              'lastLocationUpdate': FieldValue.serverTimestamp(),
            });
          } catch (e) {
            debugPrint('[LocationTrackingService] Firestore update error: $e');
          }
        },
        onError: (e) {
          debugPrint('[LocationTrackingService] Position stream error: $e');
        },
      );
      return true;
    } catch (e) {
      debugPrint('[LocationTrackingService] Error initializing tracking stream: $e');
      return false;
    }
  }

  /// Stops the GPS location stream and clears active tracking state.
  static Future<void> stopTracking() async {
    if (_positionStreamSub != null) {
      await _positionStreamSub!.cancel();
      _positionStreamSub = null;
    }

    if (_activeDonationId != null) {
      try {
        await FirebaseFirestore.instance
            .collection('donations')
            .doc(_activeDonationId)
            .update({
          'lastLocationUpdate': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('[LocationTrackingService] Error updating stop time: $e');
      }
      _activeDonationId = null;
    }
  }
}
