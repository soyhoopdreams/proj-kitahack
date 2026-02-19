import 'dart:async'; 
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // 1. Initial Camera Position (Masjid Jamek Area)
  static const LatLng _klCity = LatLng(3.1490, 101.6965);
  
  final Completer<GoogleMapController> _controller = Completer();

  // 2. Define the collection to store polygons
  final Set<Polygon> _polygons = {};

  @override
  void initState() {
    super.initState();
    _setDummyFloodArea(); // Load polygon on startup
  }

  // 3. Create the Dummy Flood Polygon
  void _setDummyFloodArea() {
    List<LatLng> floodPoints = [
      const LatLng(3.1495, 101.6950),
      const LatLng(3.1505, 101.6960),
      const LatLng(3.1500, 101.6980),
      const LatLng(3.1480, 101.6975),
      const LatLng(3.1485, 101.6955),
    ];

    setState(() {
      _polygons.add(
        Polygon(
          polygonId: const PolygonId('flood_zone_1'),
          points: floodPoints,
          strokeColor: Colors.red,
          strokeWidth: 2,
          fillColor: Colors.red.withOpacity(0.3), // Transparent red
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ResilienceBuilder (KL)'),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
      ),
      body: GoogleMap(
        mapType: MapType.normal,
        initialCameraPosition: const CameraPosition(
          target: _klCity,
          zoom: 15.5,
        ),
        // 4. Pass the polygons to the map
        polygons: _polygons, 
        markers: {},
        onMapCreated: (GoogleMapController controller) {
          _controller.complete(controller);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Placeholder for Camera action
        }, 
        label: const Text('REPORT FLOOD'),
        icon: const Icon(Icons.camera_alt),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
    );
  }
}