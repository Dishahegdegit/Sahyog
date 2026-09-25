import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../constants/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../models/ngo/donation_model.dart';
import '../../services/routing_service.dart';
import '../../widgets/animated_driver_marker.dart';
import '../../widgets/donor_notification_bell.dart';

class DonorMapScreen extends StatefulWidget {
  final Function(int)? onTabChange;

  const DonorMapScreen({super.key, this.onTabChange});

  @override
  State<DonorMapScreen> createState() => _DonorMapScreenState();
}

class _DonorMapScreenState extends State<DonorMapScreen> {
  final MapController _mapController = MapController();
  final String _currentDonorId = FirebaseAuth.instance.currentUser?.uid ?? '';

  DonationModel? _selectedDonation;
  List<LatLng> _routePolyline = [];
  bool _isLoadingRoute = false;

  static const LatLng _defaultCenter = LatLng(19.0760, 72.8777);

  Future<void> _loadRoute(DonationModel donation) async {
    setState(() {
      _selectedDonation = donation;
      _isLoadingRoute = true;
      _routePolyline = [];
    });

    final pickupLat = donation.latitude ?? 19.0760;
    final pickupLng = donation.longitude ?? 72.8777;
    final pickupPos = LatLng(pickupLat, pickupLng);

    // Default NGO hub position or offset
    final ngoPos = LatLng(pickupLat + 0.025, pickupLng + 0.020);

    final points = await RoutingService.fetchRoute(from: pickupPos, to: ngoPos);

    if (mounted) {
      setState(() {
        _routePolyline = points;
        _isLoadingRoute = false;
      });

      if (points.isNotEmpty) {
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(points),
            padding: const EdgeInsets.all(60),
          ),
        );
      }
    }
  }

  Widget _buildTopAppBar() {
    final user = FirebaseAuth.instance.currentUser;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: user != null
          ? FirebaseFirestore.instance.collection('donors').doc(user.uid).snapshots()
          : null,
      builder: (context, snapshot) {
        String profileUrl = '';
        if (snapshot.hasData && snapshot.data!.exists) {
          profileUrl = snapshot.data!.data()?['profileImageUrl'] ?? '';
        }

        return Container(
          width: double.infinity,
          color: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.volunteer_activism, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Text(
                            'Sahyog',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          Text(
                            'My Delivery Route',
                            style: TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const DonorNotificationBell(size: 24),
                      const SizedBox(width: 12),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => widget.onTabChange?.call(4),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.white.withValues(alpha: 0.25),
                            backgroundImage: profileUrl.isNotEmpty ? NetworkImage(profileUrl) : null,
                            child: profileUrl.isEmpty ? const Icon(Icons.person, color: Colors.white, size: 18) : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopAppBar(),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('donations')
                    .where('donorId', isEqualTo: _currentDonorId)
                    .snapshots(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];
          final activeDonations = docs
              .map((d) => DonationModel.fromMap(d.data(), d.id))
              .where((d) {
                final status = d.status.toLowerCase();
                return status != 'delivered' && status != 'cancelled' && status != 'completed';
              })
              .toList();

          if (_selectedDonation == null && activeDonations.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _selectedDonation == null) {
                _loadRoute(activeDonations.first);
              }
            });
          }

          final currentSelected = _selectedDonation != null
              ? activeDonations.firstWhere(
                  (d) => d.id == _selectedDonation!.id,
                  orElse: () => _selectedDonation!,
                )
              : (activeDonations.isNotEmpty ? activeDonations.first : null);

          final realGps = (currentSelected?.driverLatitude != null && currentSelected?.driverLongitude != null)
              ? LatLng(currentSelected!.driverLatitude!, currentSelected.driverLongitude!)
              : null;

          return Column(
            children: [
              // Map View
              Expanded(
                flex: 5,
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: const MapOptions(
                        initialCenter: _defaultCenter,
                        initialZoom: 12.0,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.sahyog.app',
                        ),
                        if (_routePolyline.isNotEmpty)
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: _routePolyline,
                                color: AppColors.primary,
                                strokeWidth: 4.5,
                              ),
                            ],
                          ),
                        MarkerLayer(
                          markers: activeDonations.map((d) {
                            final lat = d.latitude ?? 19.0760;
                            final lng = d.longitude ?? 72.8777;
                            final isSelected = currentSelected?.id == d.id;
                            return Marker(
                              point: LatLng(lat, lng),
                              width: 44,
                              height: 44,
                              child: GestureDetector(
                                onTap: () => _loadRoute(d),
                                child: AnimatedScale(
                                  scale: isSelected ? 1.2 : 1.0,
                                  duration: const Duration(milliseconds: 200),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isSelected ? AppColors.primary : Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: AppColors.primary, width: 2.5),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primary.withValues(alpha: 0.35),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      Icons.inventory_2_rounded,
                                      size: 20,
                                      color: isSelected ? Colors.white : AppColors.primary,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        if (_routePolyline.isNotEmpty)
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: _routePolyline.last,
                                width: 44,
                                height: 44,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade600,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.green.withValues(alpha: 0.4),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.shield_rounded,
                                    size: 20,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        if (_routePolyline.isNotEmpty || realGps != null)
                          AnimatedDriverMarker(
                            polyline: _routePolyline,
                            realGpsPosition: realGps,
                          ),
                      ],
                    ),
                    if (_isLoadingRoute)
                      Container(
                        color: Colors.black.withValues(alpha: 0.2),
                        child: const Center(
                          child: CircularProgressIndicator(color: AppColors.primary),
                        ),
                      ),
                  ],
                ),
              ),

              // Active Deliveries Sheet
              Expanded(
                flex: 4,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Active Deliveries (${activeDonations.length})',
                              style: GoogleFonts.publicSans(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: c.textPrimary,
                              ),
                            ),
                            if (_selectedDonation != null)
                              TextButton(
                                onPressed: () => setState(() {
                                  _selectedDonation = null;
                                  _routePolyline = [];
                                }),
                                child: const Text('Clear Route'),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: activeDonations.isEmpty
                            ? Center(
                                child: Text(
                                  'No active deliveries in transit.',
                                  style: TextStyle(color: c.textSecondary),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: activeDonations.length,
                                itemBuilder: (context, index) {
                                  final d = activeDonations[index];
                                  final isSelected = _selectedDonation?.id == d.id;
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    color: isSelected
                                        ? AppColors.primary.withValues(alpha: 0.08)
                                        : c.surface,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                        color: isSelected
                                            ? AppColors.primary
                                            : c.outlineVariant,
                                      ),
                                    ),
                                    child: ListTile(
                                      onTap: () => _loadRoute(d),
                                      leading: CircleAvatar(
                                        backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                                        child: const Icon(Icons.delivery_dining, color: AppColors.primary),
                                      ),
                                      title: Text(
                                        d.foodType,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: c.textPrimary,
                                        ),
                                      ),
                                      subtitle: Text(
                                        'Status: ${d.status} • Pickup: ${d.pickupAddress}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 12, color: c.textSecondary),
                                      ),
                                      trailing: const Icon(Icons.chevron_right, color: AppColors.primary),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  ],
),
),
);
  }
}
