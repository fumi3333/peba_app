import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final MapController _mapController = MapController();
  LatLng _initialCenter = const LatLng(35.6812, 139.7671); // Tokyo Station
  LatLng? _selectedLocation;
  bool _isLoading = true;
  bool _isGettingLocation = false;

  Future<void> _moveToCurrentLocation() async {
    setState(() => _isGettingLocation = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw '位置情報の権限がありません';
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
         throw '位置情報が設定で無効化されています';
      }

      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      _mapController.move(LatLng(pos.latitude, pos.longitude), 16.0); // Slightly higher zoom
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('現在地を取得できませんでした: $e')));
      }
    } finally {
      if (mounted) setState(() => _isGettingLocation = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final double? lat = prefs.getDouble('work_lat');
    final double? lng = prefs.getDouble('work_lng');

    if (lat != null && lng != null) {
      _selectedLocation = LatLng(lat, lng);
      _initialCenter = _selectedLocation!;
    } else {
      // Try get current location
      try {
        final position = await Geolocator.getCurrentPosition();
        _initialCenter = LatLng(position.latitude, position.longitude);
      } catch (e) {
        // use default
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _onTapMap(TapPosition tapPosition, LatLng point) {
    setState(() {
      _selectedLocation = point;
    });
  }

  Future<void> _saveLocation() async {
    if (_selectedLocation == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('work_lat', _selectedLocation!.latitude);
    await prefs.setDouble('work_lng', _selectedLocation!.longitude);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('勤務地を保存しました')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('勤務地をピン留め'),
        actions: [
          TextButton(
            onPressed: _selectedLocation == null ? null : _saveLocation,
            child: const Text('保存', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _initialCenter,
                    initialZoom: 15.0,
                    onTap: _onTapMap,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.peba_app',
                    ),
                    if (_selectedLocation != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _selectedLocation!,
                            width: 80,
                            height: 80,
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.red,
                              size: 40,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                Positioned(
                  right: 16,
                  bottom: 32,
                  child: FloatingActionButton(
                    heroTag: 'current_loc_btn', // Unique tag
                    onPressed: _isGettingLocation ? null : _moveToCurrentLocation,
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    child: _isGettingLocation
                      ? const SizedBox(
                          width: 24, 
                          height: 24, 
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location),
                  ),
                ),
              ],
            ),
    );
  }
}
