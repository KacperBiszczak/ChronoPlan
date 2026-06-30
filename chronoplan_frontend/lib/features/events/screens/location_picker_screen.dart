import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class PickedLocation {
  final double latitude;
  final double longitude;

  const PickedLocation({
    required this.latitude,
    required this.longitude,
  });
}

class LocationPickerScreen extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;

  const LocationPickerScreen({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  late LatLng selectedPoint;

  @override
  void initState() {
    super.initState();

    selectedPoint = LatLng(
      widget.initialLatitude ?? 52.2297,
      widget.initialLongitude ?? 21.0122,
    );
  }

  void confirmLocation() {
    Navigator.of(context).pop(
      PickedLocation(
        latitude: selectedPoint.latitude,
        longitude: selectedPoint.longitude,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wybierz lokalizację'),
        actions: [
          TextButton(
            onPressed: confirmLocation,
            child: const Text('Zapisz'),
          ),
        ],
      ),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: selectedPoint,
          initialZoom: 13,
          onTap: (tapPosition, point) {
            setState(() {
              selectedPoint = point;
            });
          },
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.chronoplan_frontend',
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: selectedPoint,
                width: 48,
                height: 48,
                child: const Icon(
                  Icons.location_on,
                  color: Colors.red,
                  size: 44,
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: confirmLocation,
            icon: const Icon(Icons.check),
            label: Text(
              'Użyj: ${selectedPoint.latitude.toStringAsFixed(6)}, '
              '${selectedPoint.longitude.toStringAsFixed(6)}',
            ),
          ),
        ),
      ),
    );
  }
}