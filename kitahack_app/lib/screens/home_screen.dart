import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Default location: KL City Centre
  static const LatLng _klCity = LatLng(3.140853, 101.693207);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ResilienceBuilder (KL)'),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
      ),
      body: GoogleMap(
        initialCameraPosition: const CameraPosition(
          target: _klCity,
          zoom: 14.0,
        ),
        // Where we will add the Heatmap/Polygons later
        markers: {},
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: Navigate to Camera Screen
        }, 
        label: const Text('REPORT FLOOD'),
        icon: const Icon(Icons.camera_alt),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
    );
  }
}