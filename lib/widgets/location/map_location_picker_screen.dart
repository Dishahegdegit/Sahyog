import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../constants/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../services/geocoding_helper.dart';

/// Full-screen map picker: top search, tap-to-move pin, pan/zoom.
class MapLocationPickerScreen extends StatefulWidget {
  const MapLocationPickerScreen({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.initialAddress,
    this.title = 'Select Location on Map',
  });

  final double? initialLatitude;
  final double? initialLongitude;
  final String? initialAddress;
  final String title;

  @override
  State<MapLocationPickerScreen> createState() => _MapLocationPickerScreenState();
}

class _MapLocationPickerScreenState extends State<MapLocationPickerScreen> {
  static const LatLng _indiaCenter = LatLng(20.5937, 78.9629);
  static const double _minZoom = 3;
  static const double _maxZoom = 18;

  late final MapController _mapController;
  late final TextEditingController _searchController;
  late LatLng _selected;
  late double _zoom;

  String _address = '';
  bool _resolving = false;
  bool _searching = false;
  List<Map<String, dynamic>> _suggestions = [];
  Timer? _searchDebounce;
  Timer? _resolveDebounce;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _searchController = TextEditingController(text: widget.initialAddress?.trim() ?? '');
    _selected = LatLng(
      widget.initialLatitude ?? _indiaCenter.latitude,
      widget.initialLongitude ?? _indiaCenter.longitude,
    );
    _zoom = widget.initialLatitude != null ? 15 : 5;
    _address = widget.initialAddress?.trim() ?? '';
    if (_address.isEmpty) {
      _scheduleResolve(_selected, updateSearchField: true);
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _resolveDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _movePinTo(LatLng point, {double? zoom, String? knownAddress, bool updateSearchField = true}) {
    final nextZoom = zoom ?? (_zoom < 14 ? 15.0 : _zoom);
    setState(() {
      _selected = point;
      _zoom = nextZoom;
      _suggestions = [];
      if (knownAddress != null && knownAddress.isNotEmpty) {
        _address = knownAddress;
        _resolving = false;
        if (updateSearchField) {
          _searchController.text = knownAddress;
        }
      } else {
        _resolving = true;
      }
    });
    _mapController.move(point, nextZoom);
    if (knownAddress == null || knownAddress.isEmpty) {
      _scheduleResolve(point, updateSearchField: updateSearchField);
    }
  }

  void _scheduleResolve(LatLng point, {required bool updateSearchField}) {
    _resolveDebounce?.cancel();
    _resolveDebounce = Timer(const Duration(milliseconds: 280), () {
      _resolveAddress(point, updateSearchField: updateSearchField);
    });
  }

  Future<void> _resolveAddress(LatLng point, {required bool updateSearchField}) async {
    final address = await GeocodingHelper.reverseGeocode(point.latitude, point.longitude);
    if (!mounted) return;
    if ((_selected.latitude - point.latitude).abs() > 0.00001 ||
        (_selected.longitude - point.longitude).abs() > 0.00001) {
      return;
    }
    setState(() {
      _address = address;
      _resolving = false;
      if (updateSearchField) {
        _searchController.text = address;
      }
    });
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    // Tap moves the locator to that exact area.
    _movePinTo(point, zoom: (_zoom < 14 ? 15.0 : _zoom));
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.length < 3) {
      setState(() => _suggestions = []);
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 550), () {
      _runSearch(trimmed, autoSelectTop: true);
    });
  }

  Future<void> _runSearch(String query, {required bool autoSelectTop}) async {
    setState(() => _searching = true);
    final results = await GeocodingHelper.searchAddress(query, limit: 6);
    if (!mounted) return;

    setState(() {
      _suggestions = results;
      _searching = false;
    });

    if (autoSelectTop && results.isNotEmpty) {
      await _selectSuggestion(results.first);
    } else if (autoSelectTop && results.isEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not find that location. Try another search or tap the map.'),
          backgroundColor: AppColors.statusPending,
        ),
      );
    }
  }

  Future<void> _selectSuggestion(Map<String, dynamic> suggestion) async {
    final display = suggestion['display'] as String? ?? '';
    final lat = suggestion['lat'] as double?;
    final lng = suggestion['lng'] as double?;
    if (lat == null || lng == null) return;

    FocusScope.of(context).unfocus();
    _movePinTo(
      LatLng(lat, lng),
      zoom: 15,
      knownAddress: display.isNotEmpty ? display : null,
      updateSearchField: true,
    );
  }

  Future<void> _submitSearch() async {
    final query = _searchController.text.trim();
    if (query.length < 3) return;
    await _runSearch(query, autoSelectTop: true);
  }

  void _zoomBy(double delta) {
    final next = (_zoom + delta).clamp(_minZoom, _maxZoom);
    _mapController.move(_mapController.camera.center, next);
    setState(() => _zoom = next);
  }

  void _confirm() {
    Navigator.pop(
      context,
      MapLocationResult(
        address: _address.isNotEmpty
            ? _address
            : '${_selected.latitude.toStringAsFixed(5)}, ${_selected.longitude.toStringAsFixed(5)}',
        latitude: _selected.latitude,
        longitude: _selected.longitude,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surface,
        foregroundColor: c.textPrimary,
        elevation: 0.5,
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _resolving ? null : _confirm,
            child: const Text(
              'Confirm',
              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _selected,
                    initialZoom: _zoom,
                    minZoom: _minZoom,
                    maxZoom: _maxZoom,
                    onTap: _onMapTap,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.drag |
                          InteractiveFlag.flingAnimation |
                          InteractiveFlag.pinchZoom |
                          InteractiveFlag.pinchMove |
                          InteractiveFlag.doubleTapZoom |
                          InteractiveFlag.scrollWheelZoom |
                          InteractiveFlag.doubleTapDragZoom,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                      subdomains: const ['a', 'b', 'c', 'd'],
                      userAgentPackageName: 'com.example.sahyog',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _selected,
                          width: 52,
                          height: 52,
                          alignment: Alignment.topCenter,
                          child: const Icon(
                            Icons.location_on,
                            color: AppColors.primary,
                            size: 52,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Top search bar (replaces instruction banner)
                Positioned(
                  left: 12,
                  right: 12,
                  top: 12,
                  child: Column(
                    children: [
                      Material(
                        color: c.surface,
                        elevation: 3,
                        borderRadius: BorderRadius.circular(12),
                        child: TextField(
                          controller: _searchController,
                          textInputAction: TextInputAction.search,
                          onChanged: _onSearchChanged,
                          onSubmitted: (_) => _submitSearch(),
                          decoration: InputDecoration(
                            hintText: 'Search location...',
                            hintStyle: TextStyle(color: c.textHint, fontSize: 14),
                            prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                            suffixIcon: _searching
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                    ),
                                  )
                                : IconButton(
                                    tooltip: 'Find location',
                                    onPressed: _submitSearch,
                                    icon: const Icon(Icons.arrow_forward, color: AppColors.primary),
                                  ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          ),
                        ),
                      ),
                      if (_suggestions.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Material(
                          color: c.surface,
                          elevation: 3,
                          borderRadius: BorderRadius.circular(12),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 220),
                            child: ListView.separated(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              itemCount: _suggestions.length,
                              separatorBuilder: (_, _) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final item = _suggestions[index];
                                return ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.place_outlined, color: AppColors.primary, size: 20),
                                  title: Text(
                                    item['display'] as String? ?? '',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 13, color: c.textPrimary),
                                  ),
                                  onTap: () => _selectSuggestion(item),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                Positioned(
                  right: 16,
                  bottom: 16,
                  child: Column(
                    children: [
                      _ZoomButton(icon: Icons.add, onTap: () => _zoomBy(1)),
                      const SizedBox(height: 8),
                      _ZoomButton(icon: Icons.remove, onTap: () => _zoomBy(-1)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              decoration: BoxDecoration(
                color: c.surface,
                border: Border(top: BorderSide(color: c.borderLight)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selected address',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: c.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (_resolving)
                    Row(
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                        ),
                        const SizedBox(width: 10),
                        Text('Updating location...', style: TextStyle(color: c.textSecondary)),
                      ],
                    )
                  else
                    Text(
                      _address.isEmpty ? 'No address yet' : _address,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'Pin: ${_selected.latitude.toStringAsFixed(5)}, ${_selected.longitude.toStringAsFixed(5)}',
                    style: TextStyle(fontSize: 12, color: c.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _resolving ? null : _confirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'Use This Location',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoomButton extends StatelessWidget {
  const _ZoomButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.surface,
      elevation: 2,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: AppColors.primary),
        ),
      ),
    );
  }
}
