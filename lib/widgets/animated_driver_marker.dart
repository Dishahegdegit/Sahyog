import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../constants/app_colors.dart';

/// Renders a motorcycle/delivery icon at the volunteer's exact live location.
/// Uses [realGpsPosition] for real-time live GPS tracking if provided.
/// Otherwise renders statically at the pickup point until live tracking begins.
class AnimatedDriverMarker extends StatelessWidget {
  final List<LatLng> polyline;
  final LatLng? realGpsPosition;
  final Color markerColor;
  final IconData icon;

  const AnimatedDriverMarker({
    super.key,
    required this.polyline,
    this.realGpsPosition,
    this.markerColor = AppColors.primary,
    this.icon = Icons.delivery_dining_rounded,
  });

  @override
  Widget build(BuildContext context) {
    // 1. If real live GPS coordinates are available from volunteer device:
    if (realGpsPosition != null) {
      return MarkerLayer(
        markers: [
          Marker(
            point: realGpsPosition!,
            width: 48,
            height: 48,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: markerColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: markerColor.withValues(alpha: 0.45),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: const Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // 2. If no polyline or GPS available, render nothing
    if (polyline.isEmpty) return const SizedBox.shrink();

    // 3. Static fallback position at pickup point (does NOT continuously move in fake loops)
    final staticPos = polyline.first;
    return MarkerLayer(
      markers: [
        Marker(
          point: staticPos,
          width: 44,
          height: 44,
          child: Container(
            decoration: BoxDecoration(
              color: markerColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: markerColor.withValues(alpha: 0.45),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ],
    );
  }
}
