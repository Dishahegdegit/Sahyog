import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../constants/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../services/geocoding_helper.dart';
import 'map_location_picker_screen.dart';

/// Screenshot-style map block:
/// title + grayscale map card with "Select Location on Map" + address field.
class LocationMapSection extends StatefulWidget {
  const LocationMapSection({
    super.key,
    required this.addressController,
    required this.latitude,
    required this.longitude,
    required this.onLocationChanged,
    this.title = 'Pickup Location or Drop-off Center',
    this.addressHint = 'Enter specific address',
    this.validator,
    this.enabled = true,
  });

  final TextEditingController addressController;
  final double? latitude;
  final double? longitude;
  final void Function(String address, double latitude, double longitude) onLocationChanged;
  final String title;
  final String addressHint;
  final FormFieldValidator<String>? validator;
  final bool enabled;

  @override
  State<LocationMapSection> createState() => _LocationMapSectionState();
}

class _LocationMapSectionState extends State<LocationMapSection> {
  static const LatLng _indiaCenter = LatLng(20.5937, 78.9629);

  final MapController _previewController = MapController();
  Timer? _debounce;
  List<Map<String, dynamic>> _suggestions = [];
  bool _searching = false;

  LatLng get _center {
    if (widget.latitude != null && widget.longitude != null) {
      return LatLng(widget.latitude!, widget.longitude!);
    }
    return _indiaCenter;
  }

  @override
  void didUpdateWidget(covariant LocationMapSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.latitude != oldWidget.latitude || widget.longitude != oldWidget.longitude) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        try {
          _previewController.move(_center, widget.latitude != null ? 12 : 4.2);
        } catch (_) {}
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _openMapPicker() async {
    if (!widget.enabled) return;
    final result = await Navigator.of(context).push<MapLocationResult>(
      MaterialPageRoute(
        builder: (_) => MapLocationPickerScreen(
          initialLatitude: widget.latitude,
          initialLongitude: widget.longitude,
          initialAddress: widget.addressController.text.trim(),
        ),
      ),
    );
    if (result == null || !mounted) return;
    widget.addressController.text = result.address;
    setState(() => _suggestions = []);
    widget.onLocationChanged(result.address, result.latitude, result.longitude);
  }

  void _onAddressChanged(String value) {
    _debounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.length < 3) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), () {
      _search(trimmed);
    });
  }

  Future<void> _search(String query) async {
    setState(() => _searching = true);
    final results = await GeocodingHelper.searchAddress(query);
    if (!mounted) return;
    setState(() {
      _suggestions = results;
      _searching = false;
    });
  }

  Future<void> _selectSuggestion(Map<String, dynamic> suggestion) async {
    final display = suggestion['display'] as String? ?? '';
    final lat = suggestion['lat'] as double?;
    final lng = suggestion['lng'] as double?;
    if (display.isEmpty || lat == null || lng == null) return;
    widget.addressController.text = display;
    setState(() => _suggestions = []);
    widget.onLocationChanged(display, lat, lng);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Address set on map pin.'),
        backgroundColor: AppColors.statusDelivered,
      ),
    );
  }

  /// Resolve free-typed address text into pin + coordinates.
  Future<void> _confirmTypedAddress() async {
    if (!widget.enabled) return;
    final query = widget.addressController.text.trim();
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please type an address first.')),
      );
      return;
    }

    setState(() {
      _searching = true;
      _suggestions = [];
    });

    try {
      final result = await GeocodingHelper.resolveAddress(query);
      if (!mounted) return;

      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not find that address. Try map or another search.'),
            backgroundColor: AppColors.statusPending,
          ),
        );
        return;
      }

      widget.addressController.text = result.address;
      widget.onLocationChanged(result.address, result.latitude, result.longitude);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Address confirmed and synced with map pin.'),
          backgroundColor: AppColors.statusDelivered,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Address lookup failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasPin = widget.latitude != null && widget.longitude != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: c.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        // Grayscale map preview card + centered CTA
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 180,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                AbsorbPointer(
                  child: FlutterMap(
                    mapController: _previewController,
                    options: MapOptions(
                      initialCenter: _center,
                      initialZoom: hasPin ? 12 : 4.2,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.none,
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
                          ..._decorativePins(),
                          if (hasPin)
                            Marker(
                              point: LatLng(widget.latitude!, widget.longitude!),
                              width: 40,
                              height: 40,
                              child: const Icon(
                                Icons.location_on,
                                color: AppColors.primary,
                                size: 36,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Soft wash so button stays readable
                Container(color: c.surface.withValues(alpha: 0.08)),
                Center(
                  child: Material(
                    color: AppColors.primary,
                    elevation: 3,
                    shadowColor: AppColors.primary.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: widget.enabled ? _openMapPicker : null,
                      borderRadius: BorderRadius.circular(10),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_on_outlined, color: Colors.white, size: 22),
                            SizedBox(width: 8),
                            Text(
                              'Select Location on Map',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: widget.addressController,
          enabled: widget.enabled,
          maxLines: 2,
          textInputAction: TextInputAction.done,
          onChanged: widget.enabled ? _onAddressChanged : null,
          onFieldSubmitted: widget.enabled ? (_) => _confirmTypedAddress() : null,
          validator: widget.validator,
          style: TextStyle(color: c.textPrimary),
          decoration: InputDecoration(
            hintText: widget.addressHint,
            hintStyle: TextStyle(color: c.textHint),
            helperText: widget.enabled ? 'Type address, then tap ✓ to set pin on map' : null,
            filled: true,
            fillColor: c.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            suffixIcon: widget.enabled
                ? (_searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        tooltip: 'Set typed address on map',
                        onPressed: _confirmTypedAddress,
                        icon: const Icon(Icons.check_circle, color: AppColors.primary),
                      ))
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: c.borderLight),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: c.borderLight),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
        if (_suggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.borderLight),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _suggestions.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final suggestion = _suggestions[index];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.place_outlined, color: AppColors.primary, size: 20),
                  title: Text(
                    suggestion['display'] as String? ?? '',
                    style: TextStyle(fontSize: 13, color: c.textPrimary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => _selectSuggestion(suggestion),
                );
              },
            ),
          ),
        ],
        if (hasPin) ...[
          const SizedBox(height: 8),
          Text(
            'Pin synced: ${widget.latitude!.toStringAsFixed(5)}, ${widget.longitude!.toStringAsFixed(5)}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.statusDelivered,
            ),
          ),
        ],
      ],
    );
  }

  /// Soft scattered pins for the muted map look from the reference UI.
  List<Marker> _decorativePins() {
    const points = <LatLng>[
      LatLng(28.6139, 77.2090),
      LatLng(19.0760, 72.8777),
      LatLng(12.9716, 77.5946),
      LatLng(22.5726, 88.3639),
      LatLng(13.0827, 80.2707),
      LatLng(26.9124, 75.7873),
      LatLng(23.0225, 72.5714),
      LatLng(17.3850, 78.4867),
    ];
    return points
        .map(
          (p) => Marker(
            point: p,
            width: 18,
            height: 18,
            child: Icon(
              Icons.location_on,
              size: 16,
              color: Colors.grey.shade500.withValues(alpha: 0.55),
            ),
          ),
        )
        .toList();
  }
}
