import 'dart:async'; 
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Default location: KL City Centre (From Farell's branch)
  static const LatLng _klCity = LatLng(3.1390, 101.6869);
  
  final Completer<GoogleMapController> _controller = Completer();

  // Define the collection to store polygons (Your feature)
  final Set<Polygon> _polygons = {};

  @override
  void initState() {
    super.initState();
    _setDummyFloodArea(); // Load polygon on startup
  }

  // Create the Dummy Flood Polygon
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
          zoom: 14.5, // Zoomed out slightly so you can still see your Masjid Jamek polygon from Farell's KL City center!
        ),
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