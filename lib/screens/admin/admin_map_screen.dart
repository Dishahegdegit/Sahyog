import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../constants/app_colors.dart';

// ─────────────────────────────────────────────────────────────────
//  Data models
// ─────────────────────────────────────────────────────────────────
class _NgoPoint {
  final String id;
  final String name;
  final String address;
  final String phone;
  final String status;
  final LatLng position;
  const _NgoPoint({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    required this.status,
    required this.position,
  });
}

class _VolunteerPoint {
  final String id;
  final String name;
  final String phone;
  final String workingArea;
  final String deliveryStatus;
  final String pickupAddress;
  final String destinationAddress;
  final String donationItem;
  final LatLng position;
  const _VolunteerPoint({
    required this.id,
    required this.name,
    required this.phone,
    required this.workingArea,
    required this.deliveryStatus,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.donationItem,
    required this.position,
  });
}

// ─────────────────────────────────────────────────────────────────
//  Main Screen
// ─────────────────────────────────────────────────────────────────
class AdminMapScreen extends StatefulWidget {
  const AdminMapScreen({super.key});

  @override
  State<AdminMapScreen> createState() => _AdminMapScreenState();
}

class _AdminMapScreenState extends State<AdminMapScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  bool _isLoading = true;

  final List<_NgoPoint> _ngos = [];
  final List<_VolunteerPoint> _volunteers = [];

  // Search & Filter State
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _showFilters = false;

  // Status Filter Values
  bool _filterAvailable = true;
  bool _filterOnDelivery = true;
  bool _filterOffline = false;

  // Entity Filter Values
  bool _filterNgos = true;
  bool _filterVolunteers = true;

  // Selected details targets
  _NgoPoint? _selectedNgo;
  _VolunteerPoint? _selectedVolunteer;

  // Map tile style (OSM variants)
  int _tileStyle = 0; // 0=streets, 1=satellite-like (CartoDB), 2=topo

  static const LatLng _defaultCenter = LatLng(19.0760, 72.8777);

  static const Map<String, LatLng> _knownLocations = {
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
    'churchgate': LatLng(18.9322, 72.8264),
    'kurla': LatLng(19.0726, 72.8845),
    'ghatkopar': LatLng(19.0860, 72.9090),
    'malad': LatLng(19.1870, 72.8483),
    'goregaon': LatLng(19.1542, 72.8491),
    'kandivali': LatLng(19.2044, 72.8528),
    'vikhroli': LatLng(19.0991, 72.9234),
    'mulund': LatLng(19.1727, 72.9570),
    'vashi': LatLng(19.0771, 73.0093),
    'belapur': LatLng(19.0239, 73.0389),
    'panvel': LatLng(18.9894, 73.1175),
    'dharavi': LatLng(19.0422, 72.8554),
    'sion': LatLng(19.0415, 72.8624),
    'matunga': LatLng(19.0256, 72.8621),
    'parel': LatLng(18.9985, 72.8410),
    'lower parel': LatLng(18.9985, 72.8298),
    'santacruz': LatLng(19.0825, 72.8431),
    'vile parle': LatLng(19.0991, 72.8467),
    'khar': LatLng(19.0721, 72.8367),
  };

  // Tile URL templates
  static const List<String> _tileUrls = [
    'https://a.basemaps.cartocdn.com/light_all/{z}/{x}/{y}@2x.png', // Light clean (CartoDB)
    'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}@2x.png', // Dark mode (CartoDB)
    'https://tile.openstreetmap.org/{z}/{x}/{y}.png', // Streets (OSM)
  ];
  static const List<String> _tileLabels = ['Light', 'Dark', 'Streets'];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ─── Geocoding ─────────────────────────────────────────────────
  Future<LatLng> _resolve(String address, String uid) async {
    final clean = address.trim().toLowerCase();
    if (clean.isEmpty) return _offset(_defaultCenter, uid);
    for (final e in _knownLocations.entries) {
      if (clean.contains(e.key)) return _offset(e.value, uid);
    }
    try {
      final q = Uri.encodeComponent('$address, Mumbai, India');
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=$q&format=json&limit=1');
      final res = await http
          .get(url, headers: {'User-Agent': 'Sahyog-Admin-Map-App'})
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final list = json.decode(res.body) as List;
        if (list.isNotEmpty) {
          return LatLng(double.parse(list[0]['lat']),
              double.parse(list[0]['lon']));
        }
      }
    } catch (_) {}
    return _offset(_defaultCenter, uid);
  }

  LatLng _offset(LatLng base, String key) {
    int h = 0;
    for (int i = 0; i < key.length; i++) {
      h = key.codeUnitAt(i) + ((h << 5) - h);
    }
    return LatLng(
      base.latitude + ((h % 100) - 50) / 4000.0,
      base.longitude + (((h >> 8) % 100) - 50) / 4000.0,
    );
  }

  // ─── Data Loading ───────────────────────────────────────────────
  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    _ngos.clear();
    _volunteers.clear();
    final db = FirebaseFirestore.instance;

    try {
      // NGOs
      final ngoSnap = await db
          .collection('users')
          .where('role', isEqualTo: 'ngo')
          .get();
      for (final doc in ngoSnap.docs) {
        final d = doc.data();
        if ((d['status'] ?? 'pending') != 'approved') continue;
        final address = d['address'] ?? d['officialAddress'] ?? '';
        final pos = await _resolve(address, doc.id);
        _ngos.add(_NgoPoint(
          id: 'ngo_${doc.id}',
          name: d['name'] ?? d['organizationName'] ?? 'Approved NGO',
          address: address.isNotEmpty ? address : 'No address',
          phone: d['phone'] ?? '',
          status: 'Approved',
          position: pos,
        ));
      }

      // Volunteers
      final volSnap = await db.collection('volunteers').get();
      for (final doc in volSnap.docs) {
        final d = doc.data();
        final status = d['status'] ?? 'Available';
        final workingArea = d['workingArea'] ?? d['area'] ?? '';
        final pos = await _resolve(workingArea, doc.id);

        String pickup = d['pickupAddress'] ?? d['pickup'] ?? '';
        String destination = d['destinationAddress'] ?? d['destination'] ?? '';
        String item = d['donationItem'] ?? d['item'] ?? d['foodType'] ?? '';

        if (pickup.isEmpty && d['donationId'] != null) {
          try {
            final donDoc = await db
                .collection('donations')
                .doc(d['donationId'])
                .get();
            if (donDoc.exists) {
              final dd = donDoc.data()!;
              pickup = dd['pickupAddress'] ?? dd['address'] ?? dd['location'] ?? '';
              destination = dd['ngoAddress'] ?? dd['destinationAddress'] ?? '';
              item = dd['foodType'] ?? dd['item'] ?? dd['description'] ?? '';
            }
          } catch (_) {}
        }

        _volunteers.add(_VolunteerPoint(
          id: 'vol_${doc.id}',
          name: d['name'] ?? 'Volunteer',
          phone: d['phone'] ?? '',
          workingArea: workingArea.isNotEmpty ? workingArea : 'Not specified',
          deliveryStatus: status,
          pickupAddress: pickup.isNotEmpty ? pickup : 'Not available',
          destinationAddress: destination.isNotEmpty ? destination : 'Not available',
          donationItem: item.isNotEmpty ? item : 'Not specified',
          position: pos,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading tracking data: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  // ─── Filtered lists ─────────────────────────────────────────────
  List<_NgoPoint> get _filteredNgos {
    if (!_filterNgos) return [];
    final q = _searchQuery.trim().toLowerCase();
    return _ngos.where((n) {
      if (q.isNotEmpty &&
          !n.name.toLowerCase().contains(q) &&
          !n.address.toLowerCase().contains(q)) {
        return false;
      }
      return true;
    }).toList();
  }

  List<_VolunteerPoint> get _filteredVols {
    if (!_filterVolunteers) return [];
    final q = _searchQuery.trim().toLowerCase();
    return _volunteers.where((v) {
      if (q.isNotEmpty &&
          !v.name.toLowerCase().contains(q) &&
          !v.workingArea.toLowerCase().contains(q)) {
        return false;
      }
      final st = v.deliveryStatus.toLowerCase();
      if (st == 'on delivery' && !_filterOnDelivery) return false;
      if (st == 'available' && !_filterAvailable) return false;
      if (st != 'on delivery' && st != 'available' && !_filterOffline) return false;
      return true;
    }).toList();
  }

  void _selectNgo(_NgoPoint n) {
    setState(() {
      _selectedVolunteer = null;
      _selectedNgo = n;
    });
    _mapController.move(n.position, 14.0);
  }

  void _selectVolunteer(_VolunteerPoint v) {
    setState(() {
      _selectedNgo = null;
      _selectedVolunteer = v;
    });
    _mapController.move(v.position, 14.0);
  }

  void _fitAll() {
    final all = [
      ..._filteredNgos.map((n) => n.position),
      ..._filteredVols.map((v) => v.position),
    ];
    if (all.isEmpty) return;
    if (all.length == 1) {
      _mapController.move(all.first, 13.0);
      return;
    }
    double minLat = all.first.latitude, maxLat = all.first.latitude;
    double minLng = all.first.longitude, maxLng = all.first.longitude;
    for (final p in all) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds(
          LatLng(minLat - 0.02, minLng - 0.02),
          LatLng(maxLat + 0.02, maxLng + 0.02),
        ),
        padding: const EdgeInsets.all(60),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int ngoCount = _ngos.length;
    final int volCount = _volunteers.length;
    final int activeDel = _volunteers.where((v) => v.deliveryStatus == 'On Delivery').length;
    final int availCount = _volunteers.where((v) => v.deliveryStatus == 'Available').length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: _buildMapStack(ngoCount, volCount, activeDel, availCount),
    );
  }

  // ─── Main map stack ─────────────────────────────────────────────
  Widget _buildMapStack(int ngoCount, int volCount, int activeDel, int availCount) {
    final ngoMarkers = _filteredNgos.map((n) => Marker(
      point: n.position,
      width: 44,
      height: 44,
      child: GestureDetector(
        onTap: () => _selectNgo(n),
        child: _MarkerPin(
          icon: Icons.shield_rounded,
          color: Colors.orange,
          isSelected: _selectedNgo?.id == n.id,
        ),
      ),
    )).toList();

    final volMarkers = _filteredVols.map((v) {
      final isOnDel = v.deliveryStatus == 'On Delivery';
      return Marker(
        point: v.position,
        width: 44,
        height: 44,
        child: GestureDetector(
          onTap: () => _selectVolunteer(v),
          child: _MarkerPin(
            icon: isOnDel ? Icons.delivery_dining_rounded : Icons.person_pin_circle_rounded,
            color: isOnDel ? Colors.blue : Colors.green,
            isSelected: _selectedVolunteer?.id == v.id,
          ),
        ),
      );
    }).toList();

    return Stack(
      children: [
        // ── Real Map ──
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _defaultCenter,
            initialZoom: 11.5,
            minZoom: 5,
            maxZoom: 18,
            onTap: (tapPos, latLng) {
              setState(() {
                _selectedNgo = null;
                _selectedVolunteer = null;
              });
            },
          ),
          children: [
            TileLayer(
              urlTemplate: _tileUrls[_tileStyle],
              userAgentPackageName: 'com.sahyog.app',
              retinaMode: MediaQuery.devicePixelRatioOf(context) > 1.0,
            ),
            MarkerLayer(markers: [...ngoMarkers, ...volMarkers]),
          ],
        ),

        // ── Top Controls (Search + Filter) ──
        SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Stats chips (shown on both web and mobile now)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    _StatChip(label: 'NGOs', value: '$ngoCount', icon: Icons.shield_rounded, color: Colors.orange),
                    const SizedBox(width: 8),
                    _StatChip(label: 'Volunteers', value: '$volCount', icon: Icons.people_rounded, color: Colors.green),
                    const SizedBox(width: 8),
                    _StatChip(label: 'On Delivery', value: '$activeDel', icon: Icons.local_shipping_rounded, color: Colors.blue),
                    const SizedBox(width: 8),
                    _StatChip(label: 'Available', value: '$availCount', icon: Icons.check_circle_rounded, color: Colors.teal),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Search + Filter row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 12, offset: const Offset(0, 4))],
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) => setState(() => _searchQuery = val),
                          style: GoogleFonts.inter(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Search NGOs, volunteers, areas…',
                            hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
                            prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary, size: 20),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.close, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () {
                        setState(() => _showFilters = !_showFilters);
                      },
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: _showFilters ? AppColors.primary : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 12, offset: const Offset(0, 4))],
                        ),
                        child: Icon(Icons.filter_list_rounded, color: _showFilters ? Colors.white : AppColors.textPrimary, size: 22),
                      ),
                    ),
                  ],
                ),
              ),
              // Filter dropdown
              if (_showFilters)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Card(
                    color: Colors.white,
                    surfaceTintColor: Colors.transparent,
                    elevation: 8,
                    shadowColor: Colors.black.withValues(alpha: 0.14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('ENTITY TYPE', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.6)),
                              GestureDetector(
                                onTap: () => setState(() { _filterNgos = true; _filterVolunteers = true; _filterAvailable = true; _filterOnDelivery = true; _filterOffline = false; }),
                                child: Text('Reset all', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(spacing: 8, children: [
                            FilterChip(label: const Text('NGOs'), avatar: const Icon(Icons.shield_outlined, size: 14), selected: _filterNgos, onSelected: (v) => setState(() => _filterNgos = v), selectedColor: Colors.orange.withValues(alpha: 0.15), checkmarkColor: Colors.orange),
                            FilterChip(label: const Text('Volunteers'), avatar: const Icon(Icons.delivery_dining_outlined, size: 14), selected: _filterVolunteers, onSelected: (v) => setState(() => _filterVolunteers = v), selectedColor: Colors.blue.withValues(alpha: 0.15), checkmarkColor: Colors.blue),
                          ]),
                          const Divider(height: 14, thickness: 0.8),
                          Text('VOLUNTEER STATUS', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.6)),
                          const SizedBox(height: 6),
                          Wrap(spacing: 8, children: [
                            FilterChip(label: const Text('Available'), selected: _filterAvailable, onSelected: (v) => setState(() => _filterAvailable = v), selectedColor: Colors.green.withValues(alpha: 0.15), checkmarkColor: Colors.green),
                            FilterChip(label: const Text('On Delivery'), selected: _filterOnDelivery, onSelected: (v) => setState(() => _filterOnDelivery = v), selectedColor: Colors.blue.withValues(alpha: 0.15), checkmarkColor: Colors.blue),
                            FilterChip(label: const Text('Offline'), selected: _filterOffline, onSelected: (v) => setState(() => _filterOffline = v), selectedColor: Colors.grey.withValues(alpha: 0.15), checkmarkColor: Colors.grey),
                          ]),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // ── Bottom Detail Card ──
        if (_selectedVolunteer != null)
          Positioned(bottom: 16, left: 16, right: 16, child: _buildVolunteerCard(_selectedVolunteer!)),
        if (_selectedNgo != null)
          Positioned(bottom: 16, left: 16, right: 16, child: _buildNgoCard(_selectedNgo!)),

        // ── Floating Action Buttons ──
        Positioned(
          bottom: (_selectedVolunteer != null || _selectedNgo != null) ? 260 : 20,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MapBtn(icon: Icons.layers_rounded, onTap: () => setState(() => _tileStyle = (_tileStyle + 1) % _tileUrls.length), tooltip: _tileLabels[(_tileStyle + 1) % _tileLabels.length]),
              const SizedBox(height: 8),
              _MapBtn(icon: Icons.center_focus_strong_rounded, onTap: _fitAll, tooltip: 'Fit all'),
              const SizedBox(height: 8),
              _MapBtn(icon: Icons.my_location_rounded, onTap: () => _mapController.move(_defaultCenter, 12.0), tooltip: 'Mumbai'),
              const SizedBox(height: 8),
              _MapBtn(icon: Icons.refresh_rounded, onTap: _loadAll, tooltip: 'Refresh'),
            ],
          ),
        ),

        // ── Map style label ──
        Positioned(
          bottom: 8,
          left: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(8)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.map_outlined, size: 12, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text('© OpenStreetMap contributors', style: GoogleFonts.inter(fontSize: 9, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),

        // ── Loading Overlay ──
        if (_isLoading)
          Container(
            color: Colors.black.withValues(alpha: 0.20),
            child: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          ),
      ],
    );
  }

  // ─── Volunteer Detail Card ──────────────────────────────────────
  Widget _buildVolunteerCard(_VolunteerPoint v) {
    final bool isOnDel = v.deliveryStatus == 'On Delivery';
    return Card(
      elevation: 14,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 14, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  child: Text(
                    v.name.split(' ').take(2).map((w) => w[0]).join().toUpperCase(),
                    style: GoogleFonts.publicSans(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.primary),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(v.name, style: GoogleFonts.publicSans(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                      const SizedBox(height: 3),
                      Row(children: [
                        Container(width: 7, height: 7, decoration: BoxDecoration(color: isOnDel ? Colors.blue : Colors.green, shape: BoxShape.circle)),
                        const SizedBox(width: 5),
                        Text(v.deliveryStatus, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: isOnDel ? Colors.blue : Colors.green)),
                        const SizedBox(width: 5),
                        Flexible(child: Text('· ${v.workingArea}', overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary))),
                      ]),
                    ],
                  ),
                ),
                SizedBox(
                  width: 32, height: 32,
                  child: IconButton(padding: EdgeInsets.zero, icon: const Icon(Icons.close, size: 18), color: AppColors.textSecondary, onPressed: () => setState(() => _selectedVolunteer = null)),
                ),
              ],
            ),
            if (isOnDel) ...[
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: _RouteEndpoint(label: 'PICKUP', address: v.pickupAddress, isStart: true)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward_rounded, size: 18, color: AppColors.textSecondary),
                ),
                Expanded(child: _RouteEndpoint(label: 'DESTINATION', address: v.destinationAddress, isStart: false)),
              ]),
              if (v.donationItem != 'Not specified') ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.inventory_2_outlined, size: 14, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(v.donationItem, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
                  ]),
                ),
              ],
            ],
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 13)),
                  onPressed: () => _callSnack(v.name, v.phone),
                  icon: const Icon(Icons.phone, size: 16),
                  label: Text('Call', style: GoogleFonts.publicSans(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.textPrimary, side: const BorderSide(color: Color(0xFFE0E0E0)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 13)),
                  onPressed: () => _mapController.move(v.position, 15.0),
                  icon: const Icon(Icons.route_rounded, size: 16),
                  label: Text('Focus', style: GoogleFonts.publicSans(fontWeight: FontWeight.bold)),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  // ─── NGO Detail Card ────────────────────────────────────────────
  Widget _buildNgoCard(_NgoPoint n) {
    return Card(
      elevation: 14,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 14, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.shield_rounded, color: Colors.orange, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(n.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.publicSans(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                      const SizedBox(height: 3),
                      Row(children: [
                        Container(width: 7, height: 7, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                        const SizedBox(width: 5),
                        Text('Active Hub · Verified', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green)),
                      ]),
                    ],
                  ),
                ),
                SizedBox(
                  width: 32, height: 32,
                  child: IconButton(padding: EdgeInsets.zero, icon: const Icon(Icons.close, size: 18), color: AppColors.textSecondary, onPressed: () => setState(() => _selectedNgo = null)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_rounded, size: 15, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(child: Text(n.address, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary))),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _callSnack(n.name, n.phone),
              icon: const Icon(Icons.phone, size: 16),
              label: Text('Contact NGO', style: GoogleFonts.publicSans(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _callSnack(String name, String phone) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.phone_in_talk, color: Colors.white),
        const SizedBox(width: 12),
        Text('Calling $name${phone.isNotEmpty ? " ($phone)" : ""}…'),
      ]),
      backgroundColor: AppColors.primary,
      duration: const Duration(seconds: 2),
    ));
  }
}

// ─── Map marker pin widget ───────────────────────────────────────
class _MarkerPin extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool isSelected;
  const _MarkerPin({required this.icon, required this.color, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: isSelected ? 1.18 : 1.0,
      duration: const Duration(milliseconds: 150),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isSelected ? color : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: color, width: isSelected ? 0 : 2.5),
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: Icon(icon, size: 18, color: isSelected ? Colors.white : color),
          ),
          CustomPaint(
            painter: _PinTailPainter(color: isSelected ? color : color.withValues(alpha: 0.8)),
            size: const Size(8, 5),
          ),
        ],
      ),
    );
  }
}

class _PinTailPainter extends CustomPainter {
  final Color color;
  const _PinTailPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Route endpoint row ──────────────────────────────────────────
class _RouteEndpoint extends StatelessWidget {
  final String label;
  final String address;
  final bool isStart;
  const _RouteEndpoint({required this.label, required this.address, required this.isStart});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 3),
          width: 8, height: 8,
          decoration: BoxDecoration(color: isStart ? AppColors.primary : Colors.green, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.8)),
              const SizedBox(height: 2),
              Text(address, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Floating Map button ─────────────────────────────────────────
class _MapBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  const _MapBtn({required this.icon, required this.onTap, required this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: Icon(icon, size: 20, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

// ─── Stat chip (mobile floating) ─────────────────────────────────
class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatChip({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(padding: const EdgeInsets.all(5), decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)), child: Icon(icon, size: 13, color: color)),
          const SizedBox(width: 7),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value, style: GoogleFonts.publicSans(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary, height: 1.1)),
              Text(label, style: GoogleFonts.inter(fontSize: 9, color: AppColors.textSecondary, height: 1.1)),
            ],
          ),
        ],
      ),
    );
  }
}
